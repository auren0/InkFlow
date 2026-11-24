import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:inkflow/hive_models/save_folder.dart';
import 'package:inkflow/hive_models/save_note.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/services/backup/attachment_store.dart';
import 'package:inkflow/services/backup/attachment_store_base.dart';
import 'package:inkflow/services/backup/backup_codec.dart';
import 'package:inkflow/services/backup/backup_models.dart';
import 'package:inkflow/services/hive_service.dart';
import 'package:inkflow/shared_preferences/note_settings_provider.dart';
import 'package:inkflow/shared_preferences/theme_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// High-level backup export/import integrated with Hive and app preferences.
///
/// Export never mutates the database. Import validates the complete archive
/// first, stages attachment files, and rolls back database changes if a write
/// fails. Hive does not offer transactions, so replace mode is implemented as
/// snapshot + clear + restore-on-error rather than claiming true atomicity.
class BackupService {
  BackupService({
    Box<SaveNote>? notesBox,
    Box<SaveNote>? archiveBox,
    Box<SaveNote>? trashNotesBox,
    Box<SaveFolder>? foldersBox,
    AttachmentStore? attachmentStore,
    Future<String> Function()? currentVersionLoader,
    Future<Map<String, Object?>> Function()? settingsLoader,
    this.useBackgroundIsolate = true,
  }) : _notesBox = notesBox,
       _archiveBox = archiveBox,
       _trashNotesBox = trashNotesBox,
       _foldersBox = foldersBox,
       _attachmentStore = attachmentStore ?? createAttachmentStore(),
       _currentVersionLoader = currentVersionLoader,
       _settingsLoader = settingsLoader;

  final Box<SaveNote>? _notesBox;
  final Box<SaveNote>? _archiveBox;
  final Box<SaveNote>? _trashNotesBox;
  final Box<SaveFolder>? _foldersBox;
  final AttachmentStore _attachmentStore;
  final Future<String> Function()? _currentVersionLoader;
  final Future<Map<String, Object?>> Function()? _settingsLoader;
  final bool useBackgroundIsolate;

  Box<SaveNote> get _notes => _notesBox ?? HiveService.getNotesBox();
  Box<SaveNote> get _archive => _archiveBox ?? HiveService.getArchiveBox();
  Box<SaveNote> get _trash => _trashNotesBox ?? HiveService.getTrashNotesBox();
  Box<SaveFolder> get _folders => _foldersBox ?? HiveService.getFoldersBox();

  Map<BackupNoteLocation, Box<SaveNote>> get _noteBoxes => {
    BackupNoteLocation.notes: _notes,
    BackupNoteLocation.archive: _archive,
    BackupNoteLocation.trash: _trash,
  };

  /// Builds a complete versioned backup from active, archived and trashed notes.
  Future<BackupExportResult> exportAll({
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.05);

    final warnings = <String>[];
    final attachments = <String, Uint8List>{};
    final sourceToRelative = <String, String>{};
    final usedNames = <String>{};
    final backupNotes = <BackupNoteData>[];

    Future<String?> exportPath(String? sourcePath) async {
      if (sourcePath == null || sourcePath.isEmpty) return null;
      final existing = sourceToRelative[sourcePath];
      if (existing != null) return existing;

      final bytes = await _attachmentStore.read(sourcePath);
      if (bytes == null) {
        warnings.add(
          AppLocalizations.translate('backup.warningAttachmentSkipped', {
            'name': _attachmentStore.displayName(sourcePath),
          }),
        );
        return null;
      }

      final baseName = _safeAttachmentFileName(
        _attachmentStore.displayName(sourcePath),
      );
      var candidate = baseName;
      var counter = 2;
      while (!usedNames.add(candidate.toLowerCase())) {
        final extension = p.extension(baseName);
        final stem = extension.isEmpty
            ? baseName
            : baseName.substring(0, baseName.length - extension.length);
        candidate = '${stem}_$counter$extension';
        counter++;
      }

      final relative = '${BackupFormat.attachmentsFolder}/$candidate';
      attachments[relative] = bytes;
      sourceToRelative[sourcePath] = relative;
      return relative;
    }

    final boxes = _noteBoxes;
    final orderedLocations = BackupNoteLocation.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    for (final location in orderedLocations) {
      final box = boxes[location]!;
      final keys = box.keys.toList()
        ..sort((a, b) => (a as num).compareTo(b as num));

      for (final key in keys) {
        final note = box.get(key);
        if (note == null) continue;

        final backgroundPath = await exportPath(note.backgroundImagePath);

        final exportedAudio = <String>[];
        final exportedAudioTitles = <String>[];
        final audioPaths = note.audioNotes ?? const <String>[];
        final audioTitles = note.audioTitles ?? const <String>[];
        for (var i = 0; i < audioPaths.length; i++) {
          final relative = await exportPath(audioPaths[i]);
          if (relative == null) continue;
          exportedAudio.add(relative);
          exportedAudioTitles.add(
            i < audioTitles.length
                ? audioTitles[i]
                : AppLocalizations.translate('note.audioNote'),
          );
        }

        final exportedAttachments = <String>[];
        for (final path in note.attachments ?? const <String>[]) {
          final relative = await exportPath(path);
          if (relative != null) exportedAttachments.add(relative);
        }

        final content = _contentForBackup(note.content);
        backupNotes.add(
          BackupNoteData(
            sourceId: key is int ? key : null,
            location: location,
            title: note.title,
            content: content.content,
            contentFormat: content.format,
            createdAt: note.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt:
                note.updatedAt ??
                note.createdAt ??
                DateTime.fromMillisecondsSinceEpoch(0),
            folderId: note.folderId,
            backgroundImagePath: backgroundPath,
            textColorValue: note.textColorValue,
            backgroundColorValue: note.backgroundColorValue,
            audioNotes: exportedAudio,
            audioTitles: exportedAudioTitles,
            attachments: exportedAttachments,
            hasCustomBackground: note.hasCustomBackground == true,
            hasCustomTextColor: note.hasCustomTextColor == true,
          ),
        );
      }
    }

    onProgress?.call(0.45);

    final folderKeys = _folders.keys.toList()
      ..sort((a, b) => (a as num).compareTo(b as num));
    final folders = <BackupFolderData>[];
    for (final key in folderKeys) {
      final folder = _folders.get(key);
      if (folder == null) continue;
      folders.add(
        BackupFolderData(
          sourceId: key is int ? key : null,
          title: folder.title,
          colorValue: folder.colorValue,
        ),
      );
    }

    final settings = await _loadPortableSettings();
    final now = DateTime.now();
    final manifest = BackupManifest(
      appVersion: await _loadAppVersion(),
      createdAt: now,
      notesCount: backupNotes.length,
      foldersCount: folders.length,
      attachmentsCount: attachments.length,
      contents: {
        'notes': BackupFormat.notesFile,
        'settings': BackupFormat.settingsFile,
        'folders': BackupFormat.foldersFile,
        'attachments': '${BackupFormat.attachmentsFolder}/',
        'includesAttachments': attachments.isNotEmpty,
      },
    );

    final data = BackupArchiveData(
      manifest: manifest,
      notes: backupNotes,
      folders: folders,
      settings: settings,
      attachments: attachments,
    );

    final bytes = await _runInBackground(_encodeBackupTask, data);
    onProgress?.call(1);

    return BackupExportResult(
      bytes: bytes,
      fileName: 'notes_backup_${_dateStamp(now)}.zip',
      notesCount: backupNotes.length,
      foldersCount: folders.length,
      attachmentsCount: attachments.length,
      warnings: warnings,
    );
  }

  /// Decodes and validates an archive, then prepares a user-facing preview.
  Future<BackupPreview> inspect(Uint8List bytes, {bool json = false}) async {
    final decoded = await _runInBackground(
      json ? _decodeJsonBackupTask : _decodeBackupTask,
      bytes,
    );

    if (!decoded.isSuccess) {
      throw BackupValidationException(
        decoded.errorCode ?? 'corrupt_archive',
        _validationMessage(decoded.errorCode),
      );
    }

    final archive = decoded.archive!;
    final boxes = _noteBoxes;
    var idConflicts = 0;
    var exactDuplicates = 0;
    var existingNotesCount = 0;

    for (final entry in boxes.entries) {
      existingNotesCount += entry.value.length;
    }

    for (final note in archive.notes) {
      final box = boxes[note.location]!;
      final id = note.sourceId;
      if (id == null) continue;
      final existing = box.get(id);
      if (existing == null) continue;

      idConflicts++;
      if (_isExactDuplicate(existing, note)) {
        exactDuplicates++;
      }
    }

    return BackupPreview(
      archive: archive,
      idConflicts: idConflicts,
      exactDuplicates: exactDuplicates,
      existingNotesCount: existingNotesCount,
    );
  }

  /// Imports a previously inspected archive.
  ///
  /// All archive checks happen before this method is called. This method only
  /// performs the reversible mutation stage.
  Future<BackupImportResult> importPreview(
    BackupPreview preview,
    BackupImportMode mode, {
    void Function(double progress)? onProgress,
  }) async {
    final archive = preview.archive;
    final warnings = <String>[];
    onProgress?.call(0.05);

    final storedAttachments = <String, String>{};
    final createdAttachments = <String>[];

    try {
      // Stage files first. If anything fails, no notes have been touched yet.
      final names = archive.attachments.keys.toList()..sort();
      for (var i = 0; i < names.length; i++) {
        final relative = names[i];
        final bytes = archive.attachments[relative]!;
        final fileName = p.basename(relative.replaceAll('\\', '/'));
        final storedPath = await _attachmentStore.persist(fileName, bytes);
        storedAttachments[relative] = storedPath;
        createdAttachments.add(storedPath);
        if (names.isNotEmpty) {
          onProgress?.call(0.05 + 0.3 * ((i + 1) / names.length));
        }
      }

      onProgress?.call(0.4);

      final result = mode == BackupImportMode.merge
          ? await _importMerge(archive, storedAttachments, warnings, onProgress)
          : await _importReplace(
              archive,
              storedAttachments,
              warnings,
              onProgress,
            );

      onProgress?.call(1);

      // Exact duplicates skipped during merge do not need their staged copies.
      // Remove attachments that no stored note references.
      final referenced = _referencedAttachmentPaths();
      var restoredAttachments = 0;
      for (final path in createdAttachments) {
        if (referenced.contains(path)) {
          restoredAttachments++;
        } else {
          await _attachmentStore.delete(path);
        }
      }

      return BackupImportResult(
        mode: mode,
        importedNotes: result.importedNotes,
        skippedDuplicates: result.skippedDuplicates,
        reassignedIds: result.reassignedIds,
        restoredFolders: result.restoredFolders,
        restoredAttachments: restoredAttachments,
        warnings: [...warnings, ...result.warnings],
      );
    } catch (error) {
      for (final path in createdAttachments) {
        await _attachmentStore.delete(path);
      }
      if (error is BackupValidationException) rethrow;
      throw BackupValidationException(
        'import_failed',
        AppLocalizations.translate('backup.errorImportFailed', {
          'error': error,
        }),
      );
    }
  }

  Future<_ImportCounters> _importMerge(
    BackupArchiveData archive,
    Map<String, String> storedAttachments,
    List<String> warnings,
    void Function(double progress)? onProgress,
  ) async {
    final addedNoteKeys = <BackupNoteLocation, List<int>>{
      for (final location in BackupNoteLocation.values) location: [],
    };
    final addedFolderKeys = <int>[];
    var importedNotes = 0;
    var skippedDuplicates = 0;
    var reassignedIds = 0;

    try {
      final folderMap = <int?, int?>{};
      final existingFolders = _folders.values.toList();
      final existingFolderKeys = _folders.keys.toList();

      for (final folder in archive.folders) {
        int? matchingKey;
        for (var i = 0; i < existingFolders.length; i++) {
          final existing = existingFolders[i];
          if (existing.title == folder.title &&
              existing.colorValue == folder.colorValue) {
            matchingKey = existingFolderKeys[i] as int?;
            break;
          }
        }

        if (matchingKey != null) {
          folderMap[folder.sourceId] = matchingKey;
        } else {
          final newFolder = SaveFolder(
            title: folder.title,
            colorValue: folder.colorValue,
          );
          final key = await _folders.add(newFolder);
          addedFolderKeys.add(key);
          folderMap[folder.sourceId] = key;
        }
      }

      final boxes = _noteBoxes;
      for (var index = 0; index < archive.notes.length; index++) {
        final backupNote = archive.notes[index];
        final box = boxes[backupNote.location]!;
        final sourceId = backupNote.sourceId;

        if (sourceId != null) {
          final existing = box.get(sourceId);
          if (existing != null) {
            if (_isExactDuplicate(existing, backupNote)) {
              skippedDuplicates++;
              continue;
            }
            reassignedIds++;
          }
        }

        final note = _toSaveNote(backupNote, folderMap, storedAttachments);
        final int key;
        if (sourceId != null && box.get(sourceId) == null) {
          await box.put(sourceId, note);
          key = sourceId;
        } else {
          key = await box.add(note);
        }
        addedNoteKeys[backupNote.location]!.add(key);
        importedNotes++;

        if (archive.notes.length >= 50 && index % 25 == 0) {
          onProgress?.call(0.4 + 0.55 * (index / archive.notes.length));
        }
      }

      return _ImportCounters(
        importedNotes: importedNotes,
        skippedDuplicates: skippedDuplicates,
        reassignedIds: reassignedIds,
        restoredFolders: addedFolderKeys.length,
        warnings: warnings,
      );
    } catch (error) {
      // Roll back only what this import added. Existing notes are untouched.
      for (final entry in addedNoteKeys.entries) {
        final box = _noteBoxes[entry.key]!;
        for (final key in entry.value) {
          await box.delete(key);
        }
      }
      for (final key in addedFolderKeys) {
        await _folders.delete(key);
      }
      rethrow;
    }
  }

  Future<_ImportCounters> _importReplace(
    BackupArchiveData archive,
    Map<String, String> storedAttachments,
    List<String> warnings,
    void Function(double progress)? onProgress,
  ) async {
    final noteSnapshot = <BackupNoteLocation, Map<dynamic, SaveNote>>{
      for (final location in BackupNoteLocation.values)
        location: Map<dynamic, SaveNote>.from(_noteBoxes[location]!.toMap()),
    };
    final folderSnapshot = Map<dynamic, SaveFolder>.from(_folders.toMap());

    try {
      final folderMap = <int?, int?>{};
      final boxes = _noteBoxes;

      for (final box in boxes.values) {
        await box.clear();
      }
      await _folders.clear();

      for (final folder in archive.folders) {
        final key = await _folders.add(
          SaveFolder(title: folder.title, colorValue: folder.colorValue),
        );
        folderMap[folder.sourceId] = key;
      }

      var importedNotes = 0;
      for (var index = 0; index < archive.notes.length; index++) {
        final backupNote = archive.notes[index];
        final box = boxes[backupNote.location]!;
        final note = _toSaveNote(backupNote, folderMap, storedAttachments);
        final sourceId = backupNote.sourceId;

        if (sourceId != null && box.get(sourceId) == null) {
          await box.put(sourceId, note);
        } else {
          await box.add(note);
        }
        importedNotes++;

        if (archive.notes.length >= 50 && index % 25 == 0) {
          onProgress?.call(0.4 + 0.55 * (index / archive.notes.length));
        }
      }

      return _ImportCounters(
        importedNotes: importedNotes,
        skippedDuplicates: 0,
        reassignedIds: 0,
        restoredFolders: archive.folders.length,
        warnings: warnings,
      );
    } catch (error) {
      // Best-effort rollback: Hive has no transactions. The snapshot is kept
      // in memory until the whole operation succeeds.
      try {
        for (final entry in noteSnapshot.entries) {
          final box = _noteBoxes[entry.key]!;
          await box.clear();
          await box.putAll(entry.value);
        }
        await _folders.clear();
        await _folders.putAll(folderSnapshot);
      } catch (rollbackError) {
        warnings.add(
          AppLocalizations.translate('backup.warningRollbackFailed', {
            'error': rollbackError,
          }),
        );
      }
      rethrow;
    }
  }

  Set<String> _referencedAttachmentPaths() {
    final paths = <String>{};
    for (final box in _noteBoxes.values) {
      for (final note in box.values) {
        if (note.backgroundImagePath != null) {
          paths.add(note.backgroundImagePath!);
        }
        paths.addAll(note.audioNotes ?? const []);
        paths.addAll(note.attachments ?? const []);
      }
    }
    return paths;
  }

  SaveNote _toSaveNote(
    BackupNoteData backupNote,
    Map<int?, int?> folderMap,
    Map<String, String> storedAttachments,
  ) {
    String? mapPath(String? relative) {
      if (relative == null || relative.isEmpty) return null;
      return storedAttachments[relative];
    }

    final audioNotes = <String>[];
    final audioTitles = <String>[];
    for (var i = 0; i < backupNote.audioNotes.length; i++) {
      final path = mapPath(backupNote.audioNotes[i]);
      if (path == null) continue;
      audioNotes.add(path);
      audioTitles.add(
        i < backupNote.audioTitles.length
            ? backupNote.audioTitles[i]
            : AppLocalizations.translate('note.audioNote'),
      );
    }

    final attachments = backupNote.attachments
        .map(mapPath)
        .whereType<String>()
        .toList();

    return SaveNote(
      title: backupNote.title,
      content: _contentString(backupNote),
      folderId: backupNote.folderId == null
          ? null
          : folderMap[backupNote.folderId],
      backgroundImagePath: mapPath(backupNote.backgroundImagePath),
      textColorValue: backupNote.textColorValue,
      backgroundColorValue: backupNote.backgroundColorValue,
      audioNotes: audioNotes,
      audioTitles: audioTitles,
      attachments: attachments,
      hasCustomBackground: backupNote.hasCustomBackground,
      hasCustomTextColor: backupNote.hasCustomTextColor,
      createdAt: backupNote.createdAt,
      updatedAt: backupNote.updatedAt,
    );
  }

  bool _isExactDuplicate(SaveNote existing, BackupNoteData note) {
    return existing.title == note.title &&
        existing.content == _contentString(note) &&
        existing.createdAt?.millisecondsSinceEpoch ==
            note.createdAt.millisecondsSinceEpoch;
  }

  String _contentString(BackupNoteData note) {
    if (note.content is String) return note.content as String;
    return jsonEncode(note.content);
  }

  ({Object content, String format}) _contentForBackup(String raw) {
    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return (content: decoded, format: 'quill-delta');
        }
        if (decoded is Map && decoded['ops'] is List) {
          return (content: decoded['ops'] as List, format: 'quill-delta');
        }
      } catch (_) {
        // Legacy plain-text content that merely starts with a bracket.
      }
    }
    return (content: raw, format: 'plain-text');
  }

  Future<Map<String, Object?>> _loadPortableSettings() async {
    if (_settingsLoader != null) return _settingsLoader();

    final prefs = await SharedPreferences.getInstance();
    final settings = <String, Object?>{};
    final keys = <String>[
      ThemeProvider.themeModeKey,
      ThemeProvider.primaryColorKey,
      ThemeProvider.fontFamilyKey,
      ThemeProvider.boldTextKey,
      ThemeProvider.languageKey,
      NoteSettingsProvider.groupByDateKey,
      NoteSettingsProvider.sortOrderKey,
    ];

    for (final key in keys) {
      final value = prefs.get(key);
      if (value != null) settings[key] = value;
    }
    return settings;
  }

  Future<String> _loadAppVersion() async {
    if (_currentVersionLoader != null) return _currentVersionLoader();

    try {
      final info = await PackageInfo.fromPlatform();
      return info.version.trim();
    } catch (_) {
      return 'unknown';
    }
  }

  Future<T> _runInBackground<T, A>(FutureOr<T> Function(A) task, A argument) {
    if (!useBackgroundIsolate) {
      return Future.value(task(argument));
    }
    return compute(task, argument);
  }

  String _validationMessage(String? code) {
    return switch (code) {
      'corrupt_archive' => AppLocalizations.translate('backup.errorCorrupt'),
      'archive_too_large' => AppLocalizations.translate('backup.errorTooLarge'),
      'too_many_entries' => AppLocalizations.translate('backup.errorTooMany'),
      'unsupported_schema' => AppLocalizations.translate('backup.errorSchema'),
      'missing_attachment' => AppLocalizations.translate(
        'backup.errorMissingAttachment',
      ),
      'unsafe_entry' ||
      'duplicate_entry' => AppLocalizations.translate('backup.errorUnsafe'),
      'zip_bomb' => AppLocalizations.translate('backup.errorZipBomb'),
      'unknown_format' ||
      'invalid_manifest' ||
      'invalid_notes' ||
      'invalid_note' ||
      'invalid_folders' ||
      'invalid_settings' ||
      'manifest_count_mismatch' => AppLocalizations.translate(
        'backup.errorInvalid',
      ),
      _ => AppLocalizations.translate('backup.errorGeneric', {
        'code': code ?? 'unknown',
      }),
    };
  }

  String _safeAttachmentFileName(String name) {
    final normalized = name.replaceAll('\\', '/');
    var safe = p.basename(normalized);
    safe = safe.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    if (safe.isEmpty || safe == '.' || safe == '..') return 'attachment';
    if (safe.length > 150) {
      final extension = p.extension(safe);
      safe = safe.substring(0, 150 - extension.length) + extension;
    }
    return safe;
  }

  String _dateStamp(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

class _ImportCounters {
  const _ImportCounters({
    required this.importedNotes,
    required this.skippedDuplicates,
    required this.reassignedIds,
    required this.restoredFolders,
    required this.warnings,
  });

  final int importedNotes;
  final int skippedDuplicates;
  final int reassignedIds;
  final int restoredFolders;
  final List<String> warnings;
}

Uint8List _encodeBackupTask(BackupArchiveData data) => BackupCodec.encode(data);

BackupDecodeResult _decodeBackupTask(Uint8List bytes) =>
    BackupCodec.decode(bytes);

BackupDecodeResult _decodeJsonBackupTask(Uint8List bytes) =>
    BackupCodec.decodeJson(bytes);
