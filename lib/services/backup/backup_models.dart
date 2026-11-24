import 'dart:typed_data';

/// Versioned InkFlow backup format.
///
/// Archive layout (schema version 1):
/// ```
/// manifest.json
/// notes.json
/// settings.json
/// folders.json
/// attachments/<files>
/// ```
class BackupFormat {
  BackupFormat._();

  static const String formatId = 'inkflow-notes-backup';
  static const int schemaVersion = 1;

  static const String manifestFile = 'manifest.json';
  static const String notesFile = 'notes.json';
  static const String settingsFile = 'settings.json';
  static const String foldersFile = 'folders.json';
  static const String attachmentsFolder = 'attachments';

  /// Hard limits protect the app from zip bombs and accidental huge imports.
  static const int maxArchiveBytes = 64 * 1024 * 1024;
  static const int maxExtractedBytes = 256 * 1024 * 1024;
  static const int maxEntryCount = 2000;
  static const int maxNoteCount = 50000;

  /// Rejects archives that expand more than this many times. Real note backups
  /// with images/audio stay far below this threshold.
  static const int maxCompressionRatio = 200;

  static const Set<String> allowedRootFiles = {
    manifestFile,
    notesFile,
    settingsFile,
    foldersFile,
  };
}

enum BackupNoteLocation {
  notes('notes'),
  archive('archive'),
  trash('trash');

  const BackupNoteLocation(this.jsonValue);

  final String jsonValue;

  static BackupNoteLocation? fromJson(Object? value) {
    for (final location in values) {
      if (location.jsonValue == value) return location;
    }
    return null;
  }
}

enum BackupImportMode { merge, replace }

class BackupManifest {
  const BackupManifest({
    required this.appVersion,
    required this.createdAt,
    required this.notesCount,
    required this.foldersCount,
    required this.attachmentsCount,
    required this.contents,
  });

  final String appVersion;
  final DateTime createdAt;
  final int notesCount;
  final int foldersCount;
  final int attachmentsCount;
  final Map<String, Object?> contents;

  Map<String, Object?> toJson() {
    return {
      'format': BackupFormat.formatId,
      'schemaVersion': BackupFormat.schemaVersion,
      'appVersion': appVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'notesCount': notesCount,
      'foldersCount': foldersCount,
      'attachmentsCount': attachmentsCount,
      'contents': contents,
    };
  }
}

class BackupNoteData {
  const BackupNoteData({
    required this.sourceId,
    required this.location,
    required this.title,
    required this.content,
    required this.contentFormat,
    required this.createdAt,
    required this.updatedAt,
    this.folderId,
    this.backgroundImagePath,
    this.textColorValue,
    this.backgroundColorValue,
    this.audioNotes = const [],
    this.audioTitles = const [],
    this.attachments = const [],
    this.hasCustomBackground = false,
    this.hasCustomTextColor = false,
  });

  /// Hive key in the source database. Used only for deterministic conflict
  /// handling; a new key is assigned when [BackupImportMode.merge] encounters
  /// an existing note that is not an exact duplicate.
  final int? sourceId;
  final BackupNoteLocation location;
  final String title;

  /// Quill Delta JSON (list/map) or a legacy plain string.
  final Object content;
  final String contentFormat;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? folderId;
  final String? backgroundImagePath;
  final int? textColorValue;
  final int? backgroundColorValue;
  final List<String> audioNotes;
  final List<String> audioTitles;
  final List<String> attachments;
  final bool hasCustomBackground;
  final bool hasCustomTextColor;

  Map<String, Object?> toJson() {
    return {
      'id': sourceId,
      'location': location.jsonValue,
      'title': title,
      'content': content,
      'contentFormat': contentFormat,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'folderId': folderId,
      'backgroundImagePath': backgroundImagePath,
      'textColorValue': textColorValue,
      'backgroundColorValue': backgroundColorValue,
      'audioNotes': audioNotes,
      'audioTitles': audioTitles,
      'attachments': attachments,
      'hasCustomBackground': hasCustomBackground,
      'hasCustomTextColor': hasCustomTextColor,
      'formatting': {'contentFormat': contentFormat},
    };
  }
}

class BackupFolderData {
  const BackupFolderData({
    required this.sourceId,
    required this.title,
    required this.colorValue,
  });

  final int? sourceId;
  final String title;
  final int colorValue;

  Map<String, Object?> toJson() {
    return {'id': sourceId, 'title': title, 'colorValue': colorValue};
  }
}

class BackupArchiveData {
  const BackupArchiveData({
    required this.manifest,
    required this.notes,
    required this.folders,
    required this.settings,
    required this.attachments,
  });

  final BackupManifest manifest;
  final List<BackupNoteData> notes;
  final List<BackupFolderData> folders;
  final Map<String, Object?> settings;
  final Map<String, Uint8List> attachments;
}

class BackupExportResult {
  const BackupExportResult({
    required this.bytes,
    required this.fileName,
    required this.notesCount,
    required this.foldersCount,
    required this.attachmentsCount,
    required this.warnings,
  });

  final Uint8List bytes;
  final String fileName;
  final int notesCount;
  final int foldersCount;
  final int attachmentsCount;
  final List<String> warnings;
}

class BackupPreview {
  const BackupPreview({
    required this.archive,
    required this.idConflicts,
    required this.exactDuplicates,
    required this.existingNotesCount,
  });

  final BackupArchiveData archive;
  final int idConflicts;
  final int exactDuplicates;
  final int existingNotesCount;

  int get notesCount => archive.notes.length;
  int get foldersCount => archive.folders.length;
  int get attachmentsCount => archive.attachments.length;
  DateTime get backupDate => archive.manifest.createdAt.toLocal();
}

class BackupImportResult {
  const BackupImportResult({
    required this.mode,
    required this.importedNotes,
    required this.skippedDuplicates,
    required this.reassignedIds,
    required this.restoredFolders,
    required this.restoredAttachments,
    required this.warnings,
  });

  final BackupImportMode mode;
  final int importedNotes;
  final int skippedDuplicates;
  final int reassignedIds;
  final int restoredFolders;
  final int restoredAttachments;
  final List<String> warnings;
}

/// Stable error codes let tests assert the security checks without depending
/// on translated text.
class BackupValidationException implements Exception {
  const BackupValidationException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class BackupDecodeResult {
  const BackupDecodeResult.success(this.archive) : errorCode = null;

  const BackupDecodeResult.failure(this.errorCode) : archive = null;

  final BackupArchiveData? archive;
  final String? errorCode;

  bool get isSuccess => archive != null;
}
