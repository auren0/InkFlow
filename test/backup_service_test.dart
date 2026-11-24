import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:inkflow/hive_models/save_folder.dart';
import 'package:inkflow/hive_models/save_note.dart';
import 'package:inkflow/services/backup/attachment_store_base.dart';
import 'package:inkflow/services/backup/backup_codec.dart';
import 'package:inkflow/services/backup/backup_models.dart';
import 'package:inkflow/services/backup/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAttachmentStore implements AttachmentStore {
  final Map<String, Uint8List> files = {};
  var _counter = 0;

  @override
  Future<Uint8List?> read(String path) async => files[path];

  @override
  Future<String> persist(String fileName, Uint8List bytes) async {
    final path = 'fake://${_counter++}/${fileName.replaceAll('\\', '/')}';
    files[path] = bytes;
    return path;
  }

  @override
  Future<void> delete(String path) async {
    files.remove(path);
  }

  @override
  String displayName(String path) {
    if (path.startsWith('fake://')) {
      return p.basename(path.replaceAll('fake://', ''));
    }
    return p.basename(path);
  }
}

SaveNote _plainNote(
  String title, {
  DateTime? createdAt,
  List<String>? attachments,
  List<String>? audioNotes,
  String? backgroundImagePath,
}) {
  final time = createdAt ?? DateTime(2026, 11, 16, 12);
  return SaveNote(
    title: title,
    content: title,
    createdAt: time,
    updatedAt: time,
    attachments: attachments,
    audioNotes: audioNotes,
    backgroundImagePath: backgroundImagePath,
  );
}

String _delta(List<Map<String, Object?>> ops) => jsonEncode(ops);

void main() {
  late Directory tempDir;
  late Box<SaveNote> notesBox;
  late Box<SaveNote> archiveBox;
  late Box<SaveNote> trashBox;
  late Box<SaveFolder> foldersBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('inkflow_backup_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SaveNoteAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SaveFolderAdapter());
    }
    notesBox = await Hive.openBox<SaveNote>('notes');
    archiveBox = await Hive.openBox<SaveNote>('archive');
    trashBox = await Hive.openBox<SaveNote>('trash_notes');
    foldersBox = await Hive.openBox<SaveFolder>('folders');
  });

  setUp(() async {
    await notesBox.clear();
    await archiveBox.clear();
    await trashBox.clear();
    await foldersBox.clear();
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  BackupService service(
    _FakeAttachmentStore store, {
    Map<String, Object?> settings = const {'notesGroupByDate': true},
    Future<Map<String, Object?>> Function()? settingsLoader,
  }) {
    return BackupService(
      notesBox: notesBox,
      archiveBox: archiveBox,
      trashNotesBox: trashBox,
      foldersBox: foldersBox,
      attachmentStore: store,
      currentVersionLoader: () async => '1.3.0',
      settingsLoader: settingsLoader ?? () async => settings,
      useBackgroundIsolate: false,
    );
  }

  group('Backup export', () {
    test('exports ordinary notes', () async {
      await notesBox.add(_plainNote('Ordinary note'));
      final store = _FakeAttachmentStore();

      final result = await service(store).exportAll();
      final preview = await service(store).inspect(result.bytes);

      expect(result.bytes, isNotEmpty);
      expect(
        result.fileName,
        matches(RegExp(r'^notes_backup_\d{4}-\d{2}-\d{2}\.zip$')),
      );
      expect(preview.notesCount, 1);
      expect(preview.archive.notes.single.title, 'Ordinary note');
      expect(preview.archive.manifest.appVersion, '1.3.0');
      expect(preview.archive.settings['notesGroupByDate'], isTrue);
    });

    test('exports rich Quill formatting as Delta JSON', () async {
      final note = _plainNote('Rich note')
        ..content = _delta([
          {
            'insert': 'Bold',
            'attributes': {'bold': true},
          },
          {
            'insert': ' Italic',
            'attributes': {'italic': true},
          },
          {'insert': '\n'},
        ]);
      await notesBox.add(note);
      final store = _FakeAttachmentStore();

      final result = await service(store).exportAll();
      final preview = await service(store).inspect(result.bytes);
      final content = preview.archive.notes.single.content;

      expect(content, isA<List>());
      final ops = (content as List).cast<Map>();
      expect(ops.first['attributes']['bold'], isTrue);
      expect(ops[1]['attributes']['italic'], isTrue);
      expect(NoteContentText.plain(content), contains('Bold Italic'));
    });

    test(
      'exports TODO checkbox state without converting to plain text',
      () async {
        final note = _plainNote('TODO')
          ..content = _delta([
            {
              'insert': 'Done',
              'attributes': {'list': 'checked'},
            },
            {'insert': '\n'},
            {
              'insert': 'Todo',
              'attributes': {'list': 'unchecked'},
            },
            {'insert': '\n'},
          ]);
        await notesBox.add(note);
        final store = _FakeAttachmentStore();

        final result = await service(store).exportAll();
        final preview = await service(store).inspect(result.bytes);
        final ops = (preview.archive.notes.single.content as List).cast<Map>();

        final lists = ops
            .map((operation) => (operation['attributes'] as Map?)?['list'])
            .whereType<String>()
            .toList();
        expect(lists, containsAll(['checked', 'unchecked']));
      },
    );

    test('only portable settings are exported', () async {
      SharedPreferences.setMockInitialValues({
        'appLanguage': 'ru',
        'accessToken': 'super-secret-token',
        'password': 'secret',
      });
      await notesBox.add(_plainNote('Note'));
      final store = _FakeAttachmentStore();
      final backup = BackupService(
        notesBox: notesBox,
        archiveBox: archiveBox,
        trashNotesBox: trashBox,
        foldersBox: foldersBox,
        attachmentStore: store,
        currentVersionLoader: () async => '1.3.0',
        useBackgroundIsolate: false,
      );

      final result = await backup.exportAll();
      final preview = await backup.inspect(result.bytes);

      expect(preview.archive.settings['appLanguage'], 'ru');
      expect(preview.archive.settings.containsKey('accessToken'), isFalse);
      expect(preview.archive.settings.containsKey('password'), isFalse);
    });

    test('export and validation work through the background isolate', () async {
      await notesBox.add(_plainNote('Isolate note'));
      final store = _FakeAttachmentStore();
      final backup = BackupService(
        notesBox: notesBox,
        archiveBox: archiveBox,
        trashNotesBox: trashBox,
        foldersBox: foldersBox,
        attachmentStore: store,
        currentVersionLoader: () async => '1.3.0',
        settingsLoader: () async => const {},
        useBackgroundIsolate: true,
      );

      final result = await backup.exportAll();
      final preview = await backup.inspect(result.bytes);

      expect(preview.notesCount, 1);
      expect(preview.archive.notes.single.title, 'Isolate note');
    });
  });

  group('Backup import', () {
    test('imports a ZIP created by the app', () async {
      await notesBox.add(
        _plainNote('Imported', createdAt: DateTime(2026, 11, 15, 8, 30)),
      );
      final store = _FakeAttachmentStore();
      final backup = service(store);
      final exported = await backup.exportAll();

      await notesBox.clear();
      final preview = await backup.inspect(exported.bytes);
      final result = await backup.importPreview(
        preview,
        BackupImportMode.merge,
      );

      expect(result.importedNotes, 1);
      expect(notesBox.length, 1);
      expect(notesBox.values.single.title, 'Imported');
    });

    test('rejects a corrupted ZIP with a clear validation error', () async {
      final store = _FakeAttachmentStore();
      final backup = service(store);

      await expectLater(
        backup.inspect(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(
          isA<BackupValidationException>().having(
            (error) => error.code,
            'code',
            'corrupt_archive',
          ),
        ),
      );
    });

    test('rejects Zip Slip paths', () async {
      final archive = Archive()
        ..addFile(ArchiveFile.string('manifest.json', '{}'))
        ..addFile(ArchiveFile.string('../evil.txt', 'evil'));
      final bytes = Uint8List.fromList(ZipEncoder().encodeBytes(archive));

      final store = _FakeAttachmentStore();
      await expectLater(
        service(store).inspect(bytes),
        throwsA(
          isA<BackupValidationException>().having(
            (error) => error.code,
            'code',
            'unsafe_entry',
          ),
        ),
      );
    });

    test('skips exact duplicates during merge', () async {
      await notesBox.add(_plainNote('Same'));
      final store = _FakeAttachmentStore();
      final backup = service(store);
      final exported = await backup.exportAll();

      final preview = await backup.inspect(exported.bytes);
      expect(preview.exactDuplicates, 1);

      final result = await backup.importPreview(
        preview,
        BackupImportMode.merge,
      );

      expect(result.skippedDuplicates, 1);
      expect(result.importedNotes, 0);
      expect(notesBox.length, 1);
    });

    test(
      'resolves an ID conflict deterministically without overwriting',
      () async {
        await notesBox.add(_plainNote('Original'));
        final store = _FakeAttachmentStore();
        final backup = service(store);
        final exported = await backup.exportAll();

        final existing = notesBox.values.single;
        existing.title = 'Edited after backup';
        await existing.save();

        final preview = await backup.inspect(exported.bytes);
        expect(preview.idConflicts, 1);
        expect(preview.exactDuplicates, 0);

        final result = await backup.importPreview(
          preview,
          BackupImportMode.merge,
        );

        expect(result.importedNotes, 1);
        expect(result.reassignedIds, 1);
        expect(notesBox.length, 2);
        expect(
          notesBox.values.map((note) => note.title),
          containsAll(['Edited after backup', 'Original']),
        );
      },
    );

    test('merges notes and keeps existing ones', () async {
      await notesBox.add(_plainNote('From backup'));
      final store = _FakeAttachmentStore();
      final backup = service(store);
      final exported = await backup.exportAll();

      await notesBox.clear();
      await notesBox.add(
        _plainNote('Existing', createdAt: DateTime(2026, 11, 17, 9)),
      );

      final preview = await backup.inspect(exported.bytes);
      final result = await backup.importPreview(
        preview,
        BackupImportMode.merge,
      );

      expect(result.importedNotes, 1);
      expect(notesBox.length, 2);
      expect(
        notesBox.values.map((note) => note.title),
        containsAll(['Existing', 'From backup']),
      );
    });

    test('replace mode removes previous notes only after validation', () async {
      await notesBox.add(_plainNote('From backup'));
      final store = _FakeAttachmentStore();
      final backup = service(store);
      final exported = await backup.exportAll();

      await notesBox.add(
        _plainNote('Will be removed', createdAt: DateTime(2026, 11, 17, 9)),
      );

      final preview = await backup.inspect(exported.bytes);
      final result = await backup.importPreview(
        preview,
        BackupImportMode.replace,
      );

      expect(result.importedNotes, 1);
      expect(notesBox.length, 1);
      expect(notesBox.values.single.title, 'From backup');
    });

    test('preserves original creation dates', () async {
      final createdAt = DateTime(2024, 5, 6, 7, 8, 9);
      await notesBox.add(_plainNote('Dated', createdAt: createdAt));
      final store = _FakeAttachmentStore();
      final backup = service(store);
      final exported = await backup.exportAll();

      await notesBox.clear();
      final preview = await backup.inspect(exported.bytes);
      await backup.importPreview(preview, BackupImportMode.replace);

      expect(
        notesBox.values.single.createdAt!.millisecondsSinceEpoch,
        createdAt.millisecondsSinceEpoch,
      );
    });
  });

  group('Full backup restore', () {
    test('export, delete, import restores notes and attachments', () async {
      final attachmentBytes = Uint8List.fromList(utf8.encode('report body'));
      final imageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final audioBytes = Uint8List.fromList([9, 8, 7]);

      final store = _FakeAttachmentStore();
      store.files['/device/report.txt'] = attachmentBytes;
      store.files['/device/cover.png'] = imageBytes;
      store.files['/device/voice.m4a'] = audioBytes;

      final note = _plainNote(
        'With attachments',
        attachments: ['/device/report.txt'],
        audioNotes: ['/device/voice.m4a'],
        backgroundImagePath: '/device/cover.png',
      );
      note.audioTitles = ['Voice'];
      await notesBox.add(note);

      final backup = service(store);
      final exported = await backup.exportAll();
      expect(exported.attachmentsCount, 3);

      await notesBox.clear();
      store.files.remove('/device/report.txt');
      store.files.remove('/device/cover.png');
      store.files.remove('/device/voice.m4a');

      final preview = await backup.inspect(exported.bytes);
      await backup.importPreview(preview, BackupImportMode.replace);

      final restored = notesBox.values.single;
      expect(restored.title, 'With attachments');
      expect(restored.attachments, hasLength(1));
      expect(restored.audioNotes, hasLength(1));
      expect(restored.audioTitles, ['Voice']);
      expect(restored.backgroundImagePath, isNotNull);
      expect(store.files[restored.attachments!.single], attachmentBytes);
      expect(store.files[restored.audioNotes!.single], audioBytes);
      expect(store.files[restored.backgroundImagePath!], imageBytes);
    });
  });

  group('Platform-independent codec', () {
    test('encodes and decodes a versioned archive without IO', () {
      final data = BackupArchiveData(
        manifest: BackupManifest(
          appVersion: '1.3.0',
          createdAt: DateTime.utc(2026, 11, 16),
          notesCount: 1,
          foldersCount: 0,
          attachmentsCount: 0,
          contents: const {'notes': BackupFormat.notesFile},
        ),
        notes: [
          BackupNoteData(
            sourceId: 1,
            location: BackupNoteLocation.notes,
            title: 'Codec',
            content: 'Plain text',
            contentFormat: 'plain-text',
            createdAt: DateTime.utc(2026, 11, 16),
            updatedAt: DateTime.utc(2026, 11, 16),
          ),
        ],
        folders: const [],
        settings: const {},
        attachments: const {},
      );

      final bytes = BackupCodec.encode(data);
      final decoded = BackupCodec.decode(bytes);

      expect(decoded.isSuccess, isTrue);
      expect(decoded.archive!.notes.single.title, 'Codec');
      expect(decoded.archive!.manifest.notesCount, 1);
    });
  });
}

/// Minimal plain-text extraction for assertions, mirroring Delta inserts.
class NoteContentText {
  static String plain(Object content) {
    if (content is! List) return content.toString();
    return content
        .whereType<Map>()
        .map((operation) => operation['insert'] ?? '')
        .join();
  }
}
