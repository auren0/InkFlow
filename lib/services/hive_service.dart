import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:note_app/hive_models/save_folder.dart';
import 'package:note_app/hive_models/save_note.dart';
import 'package:path_provider/path_provider.dart';

import 'package:path/path.dart' as p;

class HiveService {
  static Future<void> init() async {
    final String databasePath;

    if (Platform.isAndroid || Platform.isIOS) {
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
  }

  static Box<SaveNote> getNotesBox() => Hive.box<SaveNote>('notes');
  static Box<SaveNote> getArchiveBox() => Hive.box<SaveNote>('archive');
  static Box<SaveNote> getTrashNotesBox() => Hive.box<SaveNote>('trash_notes');
  static Box<SaveFolder> getTrashFoldersBox() =>
      Hive.box<SaveFolder>('trash_folders');
  static Box<SaveFolder> getFoldersBox() => Hive.box<SaveFolder>('folders');
}
