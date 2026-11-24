import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:inkflow/services/backup/backup_models.dart';

/// Pure encode/decode layer for the versioned ZIP backup.
///
/// This class deliberately avoids Hive, Flutter and `dart:io` so it can run in
/// a background isolate and compile for Web.
class BackupCodec {
  BackupCodec._();

  static Uint8List encode(BackupArchiveData data) {
    final archive = Archive();

    archive.addFile(
      ArchiveFile.string(
        BackupFormat.manifestFile,
        const JsonEncoder.withIndent('  ').convert(data.manifest.toJson()),
      ),
    );
    archive.addFile(
      ArchiveFile.string(
        BackupFormat.notesFile,
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': BackupFormat.schemaVersion,
          'notes': data.notes.map((note) => note.toJson()).toList(),
        }),
      ),
    );
    archive.addFile(
      ArchiveFile.string(
        BackupFormat.settingsFile,
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': BackupFormat.schemaVersion,
          'settings': data.settings,
        }),
      ),
    );
    archive.addFile(
      ArchiveFile.string(
        BackupFormat.foldersFile,
        const JsonEncoder.withIndent('  ').convert({
          'schemaVersion': BackupFormat.schemaVersion,
          'folders': data.folders.map((folder) => folder.toJson()).toList(),
        }),
      ),
    );

    final attachmentNames = data.attachments.keys.toList()..sort();
    for (final name in attachmentNames) {
      final bytes = data.attachments[name]!;
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    final encoded = Uint8List.fromList(ZipEncoder().encodeBytes(archive));
    if (encoded.length > BackupFormat.maxArchiveBytes) {
      throw const BackupValidationException(
        'export_too_large',
        'The backup archive is too large.',
      );
    }
    return encoded;
  }

  /// Decodes and fully validates an app-generated ZIP archive.
  ///
  /// The returned result is safe to use for the preview and import steps:
  /// paths, counts, JSON shapes and attachment references have all been
  /// checked, and decompression limits have been enforced.
  static BackupDecodeResult decode(Uint8List bytes) {
    if (bytes.length > BackupFormat.maxArchiveBytes) {
      return const BackupDecodeResult.failure('archive_too_large');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      return const BackupDecodeResult.failure('corrupt_archive');
    }

    if (archive.length > BackupFormat.maxEntryCount) {
      return const BackupDecodeResult.failure('too_many_entries');
    }

    final files = <String, Uint8List>{};
    final seenNames = <String>{};
    var totalExtracted = 0;

    for (final entry in archive) {
      final name = entry.name;

      if (entry.isSymbolicLink) {
        return const BackupDecodeResult.failure('unsafe_entry');
      }

      // Directory entries are tolerated only for the attachments folder.
      if (!entry.isFile) {
        if (name == '${BackupFormat.attachmentsFolder}/') continue;
        return const BackupDecodeResult.failure('unsafe_entry');
      }

      if (!_isAllowedEntryName(name)) {
        return const BackupDecodeResult.failure('unsafe_entry');
      }

      final lowerName = name.toLowerCase();
      if (!seenNames.add(lowerName)) {
        return const BackupDecodeResult.failure('duplicate_entry');
      }

      if (entry.size < 0 || entry.size > BackupFormat.maxExtractedBytes) {
        return const BackupDecodeResult.failure('entry_too_large');
      }

      final content = entry.readBytes();
      if (content == null) {
        return const BackupDecodeResult.failure('corrupt_archive');
      }
      if (content.length > BackupFormat.maxExtractedBytes) {
        return const BackupDecodeResult.failure('entry_too_large');
      }
      totalExtracted += content.length;
      if (totalExtracted > BackupFormat.maxExtractedBytes) {
        return const BackupDecodeResult.failure('archive_too_large');
      }
      files[name] = content;
    }

    if (totalExtracted > 8 * 1024 * 1024 &&
        bytes.isNotEmpty &&
        totalExtracted > bytes.length * BackupFormat.maxCompressionRatio) {
      return const BackupDecodeResult.failure('zip_bomb');
    }

    final manifestBytes = files[BackupFormat.manifestFile];
    final notesBytes = files[BackupFormat.notesFile];
    if (manifestBytes == null || notesBytes == null) {
      return const BackupDecodeResult.failure('missing_manifest');
    }

    final manifestMap = _decodeJsonObject(manifestBytes);
    if (manifestMap == null) {
      return const BackupDecodeResult.failure('invalid_manifest');
    }

    if (manifestMap['format'] != BackupFormat.formatId) {
      return const BackupDecodeResult.failure('unknown_format');
    }

    final schema = _asInt(manifestMap['schemaVersion']);
    if (schema == null) {
      return const BackupDecodeResult.failure('invalid_manifest');
    }
    if (schema > BackupFormat.schemaVersion) {
      return const BackupDecodeResult.failure('unsupported_schema');
    }
    if (schema != BackupFormat.schemaVersion) {
      return const BackupDecodeResult.failure('invalid_manifest');
    }

    final appVersion = _asString(manifestMap['appVersion']) ?? '';
    final createdAt = _asDate(manifestMap['createdAt']);
    final manifestNotesCount = _asInt(manifestMap['notesCount']);
    final manifestFoldersCount = _asInt(manifestMap['foldersCount']);
    final manifestAttachmentsCount = _asInt(manifestMap['attachmentsCount']);
    if (createdAt == null ||
        manifestNotesCount == null ||
        manifestFoldersCount == null ||
        manifestAttachmentsCount == null) {
      return const BackupDecodeResult.failure('invalid_manifest');
    }

    final notesRoot = _decodeJsonObject(notesBytes);
    if (notesRoot == null ||
        _asInt(notesRoot['schemaVersion']) != BackupFormat.schemaVersion ||
        notesRoot['notes'] is! List) {
      return const BackupDecodeResult.failure('invalid_notes');
    }

    final attachments = <String, Uint8List>{};
    for (final entry in files.entries) {
      if (entry.key.startsWith('${BackupFormat.attachmentsFolder}/')) {
        attachments[entry.key] = entry.value;
      }
    }

    final notesResult = _parseNotes(notesRoot['notes'] as List, attachments);
    if (notesResult.errorCode != null) {
      return BackupDecodeResult.failure(notesResult.errorCode);
    }
    final notes = notesResult.value!;
    if (notes.length > BackupFormat.maxNoteCount) {
      return const BackupDecodeResult.failure('too_many_notes');
    }

    final folders = <BackupFolderData>[];
    final foldersBytes = files[BackupFormat.foldersFile];
    if (foldersBytes != null) {
      final foldersRoot = _decodeJsonObject(foldersBytes);
      if (foldersRoot == null ||
          _asInt(foldersRoot['schemaVersion']) != BackupFormat.schemaVersion ||
          foldersRoot['folders'] is! List) {
        return const BackupDecodeResult.failure('invalid_folders');
      }
      final result = _parseFolders(foldersRoot['folders'] as List);
      if (result.errorCode != null) {
        return BackupDecodeResult.failure(result.errorCode);
      }
      folders.addAll(result.value!);
    }

    final settings = <String, Object?>{};
    final settingsBytes = files[BackupFormat.settingsFile];
    if (settingsBytes != null) {
      final settingsRoot = _decodeJsonObject(settingsBytes);
      if (settingsRoot == null ||
          _asInt(settingsRoot['schemaVersion']) != BackupFormat.schemaVersion ||
          settingsRoot['settings'] is! Map) {
        return const BackupDecodeResult.failure('invalid_settings');
      }
      settings.addAll(
        (settingsRoot['settings'] as Map).cast<String, Object?>(),
      );
    }

    if (notes.length != manifestNotesCount ||
        folders.length != manifestFoldersCount ||
        attachments.length != manifestAttachmentsCount) {
      return const BackupDecodeResult.failure('manifest_count_mismatch');
    }

    final manifest = BackupManifest(
      appVersion: appVersion,
      createdAt: createdAt,
      notesCount: manifestNotesCount,
      foldersCount: manifestFoldersCount,
      attachmentsCount: manifestAttachmentsCount,
      contents: (manifestMap['contents'] is Map)
          ? (manifestMap['contents'] as Map).cast<String, Object?>()
          : const {},
    );

    return BackupDecodeResult.success(
      BackupArchiveData(
        manifest: manifest,
        notes: notes,
        folders: folders,
        settings: settings,
        attachments: attachments,
      ),
    );
  }

  /// Parses the explicitly supported JSON variant: the same root shape as
  /// `notes.json` (`schemaVersion` + `notes`, optional `folders`/`settings`)
  /// with no attachment references. Arbitrary JSON is never guessed.
  static BackupDecodeResult decodeJson(Uint8List bytes) {
    if (bytes.length > BackupFormat.maxArchiveBytes) {
      return const BackupDecodeResult.failure('archive_too_large');
    }

    final root = _decodeJsonObject(bytes);
    if (root == null) {
      return const BackupDecodeResult.failure('invalid_json');
    }
    if (_asInt(root['schemaVersion']) != BackupFormat.schemaVersion ||
        root['notes'] is! List) {
      return const BackupDecodeResult.failure('invalid_notes');
    }

    final notesResult = _parseNotes(root['notes'] as List, const {});
    if (notesResult.errorCode != null) {
      return BackupDecodeResult.failure(notesResult.errorCode);
    }
    final notes = notesResult.value!;

    final folders = <BackupFolderData>[];
    if (root['folders'] is List) {
      final result = _parseFolders(root['folders'] as List);
      if (result.errorCode != null) {
        return BackupDecodeResult.failure(result.errorCode);
      }
      folders.addAll(result.value!);
    }

    final settings = <String, Object?>{};
    if (root['settings'] is Map) {
      settings.addAll((root['settings'] as Map).cast<String, Object?>());
    }

    return BackupDecodeResult.success(
      BackupArchiveData(
        manifest: BackupManifest(
          appVersion: 'json-import',
          createdAt: DateTime.now(),
          notesCount: notes.length,
          foldersCount: folders.length,
          attachmentsCount: 0,
          contents: const {'notes': BackupFormat.notesFile},
        ),
        notes: notes,
        folders: folders,
        settings: settings,
        attachments: const {},
      ),
    );
  }

  static _ParseResult<List<BackupNoteData>> _parseNotes(
    List rawNotes,
    Map<String, Uint8List> attachments,
  ) {
    if (rawNotes.length > BackupFormat.maxNoteCount) {
      return const _ParseResult.failure('too_many_notes');
    }

    final notes = <BackupNoteData>[];
    final ids = <String>{};

    for (final raw in rawNotes) {
      if (raw is! Map) return const _ParseResult.failure('invalid_notes');
      final map = raw.cast<String, Object?>();

      final id = _asInt(map['id']);
      final location = BackupNoteLocation.fromJson(map['location']);
      final title = _asString(map['title']);
      final content = map['content'];
      final contentFormat = _asString(map['contentFormat']) ?? 'quill-delta';
      final createdAt = _asDate(map['createdAt']);
      final updatedAt = _asDate(map['updatedAt']) ?? createdAt;

      if (id == null ||
          location == null ||
          title == null ||
          createdAt == null ||
          updatedAt == null ||
          !(content is String || content is List || content is Map)) {
        return const _ParseResult.failure('invalid_note');
      }

      if (!ids.add('${location.jsonValue}:$id')) {
        return const _ParseResult.failure('duplicate_note_id');
      }

      final backgroundPath = _asString(map['backgroundImagePath']);
      final audioNotes = _asStringList(map['audioNotes']);
      final audioTitles = _asStringList(map['audioTitles']);
      final noteAttachments = _asStringList(map['attachments']);
      if (backgroundPath == null && map['backgroundImagePath'] != null) {
        return const _ParseResult.failure('invalid_note');
      }
      if (audioNotes == null ||
          audioTitles == null ||
          noteAttachments == null) {
        return const _ParseResult.failure('invalid_note');
      }

      final paths = <String>[
        if (backgroundPath != null && backgroundPath.isNotEmpty) backgroundPath,
        ...audioNotes.where((path) => path.isNotEmpty),
        ...noteAttachments.where((path) => path.isNotEmpty),
      ];
      for (final path in paths) {
        if (!_isSafeRelativeAttachment(path) ||
            !attachments.containsKey(path)) {
          return const _ParseResult.failure('missing_attachment');
        }
      }

      notes.add(
        BackupNoteData(
          sourceId: id,
          location: location,
          title: title,
          content: content as Object,
          contentFormat: contentFormat,
          createdAt: createdAt,
          updatedAt: updatedAt,
          folderId: _asInt(map['folderId']),
          backgroundImagePath: backgroundPath,
          textColorValue: _asInt(map['textColorValue']),
          backgroundColorValue: _asInt(map['backgroundColorValue']),
          audioNotes: audioNotes,
          audioTitles: audioTitles,
          attachments: noteAttachments,
          hasCustomBackground: map['hasCustomBackground'] == true,
          hasCustomTextColor: map['hasCustomTextColor'] == true,
        ),
      );
    }

    notes.sort((a, b) {
      final byDate = a.createdAt.compareTo(b.createdAt);
      if (byDate != 0) return byDate;
      final byLocation = a.location.index.compareTo(b.location.index);
      if (byLocation != 0) return byLocation;
      return (a.sourceId ?? 0).compareTo(b.sourceId ?? 0);
    });

    return _ParseResult.success(notes);
  }

  static _ParseResult<List<BackupFolderData>> _parseFolders(List rawFolders) {
    final folders = <BackupFolderData>[];
    final ids = <int>{};

    for (final raw in rawFolders) {
      if (raw is! Map) return const _ParseResult.failure('invalid_folders');
      final map = raw.cast<String, Object?>();
      final id = _asInt(map['id']);
      final title = _asString(map['title']);
      final colorValue = _asInt(map['colorValue']);

      if (id == null || title == null || colorValue == null) {
        return const _ParseResult.failure('invalid_folders');
      }
      if (!ids.add(id)) {
        return const _ParseResult.failure('duplicate_folder_id');
      }
      folders.add(
        BackupFolderData(sourceId: id, title: title, colorValue: colorValue),
      );
    }

    folders.sort((a, b) => (a.sourceId ?? 0).compareTo(b.sourceId ?? 0));
    return _ParseResult.success(folders);
  }

  static bool _isAllowedEntryName(String name) {
    if (name.isEmpty || name.endsWith('/')) return false;
    if (!_isSafeRelativePath(name)) return false;

    if (BackupFormat.allowedRootFiles.contains(name)) return true;

    final parts = name.split('/');
    return parts.length == 2 &&
        parts[0] == BackupFormat.attachmentsFolder &&
        parts[1].isNotEmpty;
  }

  static bool _isSafeRelativePath(String path) {
    if (path.isEmpty || path.length > 240) return false;
    if (path.startsWith('/') ||
        path.contains('\\') ||
        path.contains('\x00') ||
        RegExp(r'^[A-Za-z]:').hasMatch(path)) {
      return false;
    }

    for (final segment in path.split('/')) {
      if (segment.isEmpty || segment == '.' || segment == '..') {
        return false;
      }
      if (segment.contains(RegExp(r'[\x00-\x1F]'))) return false;
    }
    return true;
  }

  static bool _isSafeRelativeAttachment(String path) {
    return _isSafeRelativePath(path) &&
        path.startsWith('${BackupFormat.attachmentsFolder}/') &&
        path.split('/').length == 2;
  }

  static Map<String, Object?>? _decodeJsonObject(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) return null;
      return decoded.cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static String? _asString(Object? value) {
    return value is String ? value : null;
  }

  static DateTime? _asDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  static List<String>? _asStringList(Object? value) {
    if (value == null) return const [];
    if (value is! List) return null;
    final result = <String>[];
    for (final item in value) {
      if (item is! String) return null;
      result.add(item);
    }
    return result;
  }
}

class _ParseResult<T> {
  const _ParseResult.success(this.value) : errorCode = null;

  const _ParseResult.failure(this.errorCode) : value = null;

  final T? value;
  final String? errorCode;
}
