import 'dart:io';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inkflow/hive_models/save_folder.dart';
import 'package:inkflow/hive_models/save_note.dart';
import 'package:path_provider/path_provider.dart';

import 'package:path/path.dart' as p;

class HiveService {
  static Future<void> init() async {
    if (kIsWeb) {
      // На web Hive хранит данные в IndexedDB, файловая система недоступна.
      await Hive.initFlutter();
    } else {
      final String databasePath;

      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        // На мобильных устройствах документы пользователя (Documents) недоступны
        // для прямой записи. Храним базу во внутреннем каталоге приложения.
        final appSupportDirectory = await getApplicationSupportDirectory();
        databasePath = p.join(appSupportDirectory.path, 'database');
      } else {
        // На десктопе оставляем базу рядом с исполняемым файлом.
        final exeDirectory = File(Platform.resolvedExecutable).parent.path;
        databasePath = p.join(exeDirectory, 'database');
      }

      await Directory(databasePath).create(recursive: true);

      Hive.init(databasePath);
    }

    Hive.registerAdapter(SaveNoteAdapter());
    Hive.registerAdapter(SaveFolderAdapter());

    // await Hive.deleteBoxFromDisk('notes');
    await Hive.openBox<SaveNote>('notes');

    // await Hive.deleteBoxFromDisk('archive');
    await Hive.openBox<SaveNote>('archive');

    // await Hive.deleteBoxFromDisk('trash_notes');
    await Hive.openBox<SaveNote>('trash_notes');

    // await Hive.deleteBoxFromDisk('trash_folders');
    await Hive.openBox<SaveFolder>('trash_folders');

    // await Hive.deleteBoxFromDisk('folders');
    await Hive.openBox<SaveFolder>('folders');

    await _migrateNoteTimestamps(Hive.box<SaveNote>('notes'));
    await _migrateNoteTimestamps(Hive.box<SaveNote>('archive'));
    await _migrateNoteTimestamps(Hive.box<SaveNote>('trash_notes'));
  }

  /// Adds [SaveNote.createdAt] to notes written by older app versions.
  ///
  /// Hive keys are monotonically increasing, so they preserve the original
  /// insertion order. Missing timestamps are spaced by one minute before the
  /// earliest known timestamp (or before startup time when no note has one).
  /// The migration is persisted immediately, so the order can never change
  /// between launches.
  static Future<void> _migrateNoteTimestamps(Box<SaveNote> box) async {
    final missing = box.values.where((note) => note.createdAt == null).toList();
    if (missing.isEmpty) return;

    final known = box.values
        .map((note) => note.createdAt)
        .whereType<DateTime>()
        .toList();
    final base = known.isEmpty
        ? DateTime.now()
        : known.reduce((a, b) => a.isBefore(b) ? a : b);

    final keys = box.keys.toList()
      ..sort((a, b) => (a as num).compareTo(b as num));

    for (var index = 0; index < keys.length; index++) {
      final note = box.get(keys[index]);
      if (note == null || note.createdAt != null) continue;

      final createdAt = base.subtract(Duration(minutes: keys.length - index));
      note.createdAt = createdAt;
      note.updatedAt ??= createdAt;
      await note.save();
    }
  }

  static Box<SaveNote> getNotesBox() => Hive.box<SaveNote>('notes');
  static Box<SaveNote> getArchiveBox() => Hive.box<SaveNote>('archive');
  static Box<SaveNote> getTrashNotesBox() => Hive.box<SaveNote>('trash_notes');
  static Box<SaveFolder> getTrashFoldersBox() =>
      Hive.box<SaveFolder>('trash_folders');
  static Box<SaveFolder> getFoldersBox() => Hive.box<SaveFolder>('folders');
}
