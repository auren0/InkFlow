import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:inkflow/hive_models/save_folder.dart';
import 'package:inkflow/hive_models/save_note.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/note_provider.dart';
import 'package:inkflow/screens/create_note_screen.dart';
import 'package:inkflow/screens/home_screen.dart';
import 'package:inkflow/services/note_sorting.dart';
import 'package:inkflow/shared_preferences/note_settings_provider.dart';
import 'package:inkflow/shared_preferences/theme_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fast in-memory provider for widget tests so widget tests do not block on
/// real OS disk I/O in Flutter's simulated [FakeAsync] event loop.
class FakeNoteProvider extends NoteProvider {
  final List<SaveNote> _fakeNotes = [];
  final List<SaveNote> _fakeArchive = [];
  final List<SaveNote> _fakeTrash = [];
  final List<SaveFolder> _fakeFolders = [];

  @override
  List<SaveNote> get notes => List.unmodifiable(_fakeNotes);

  @override
  List<SaveNote> get archive => List.unmodifiable(_fakeArchive);

  @override
  List<SaveNote> get trashNotes => List.unmodifiable(_fakeTrash);

  @override
  List<SaveFolder> get folders => List.unmodifiable(_fakeFolders);

  @override
  Future<void> addNote(SaveNote note) async {
    final now = DateTime.now();
    note.createdAt ??= now;
    note.updatedAt ??= note.createdAt;
    _fakeNotes.add(note);
    notifyListeners();
  }

  @override
  Future<void> saveNoteChanges(SaveNote note) async {
    note.updatedAt = DateTime.now();
    notifyListeners();
  }

  @override
  Future<void> updateNote(SaveNote oldNote, SaveNote newNote) async {
    oldNote
      ..title = newNote.title
      ..content = newNote.content
      ..folderId = newNote.folderId
      ..backgroundImagePath = newNote.backgroundImagePath
      ..textColorValue = newNote.textColorValue
      ..backgroundColorValue = newNote.backgroundColorValue
      ..audioNotes = newNote.audioNotes
      ..audioTitles = newNote.audioTitles
      ..attachments = newNote.attachments
      ..hasCustomBackground = newNote.hasCustomBackground
      ..hasCustomTextColor = newNote.hasCustomTextColor
      ..updatedAt = DateTime.now();
    notifyListeners();
  }

  @override
  void addToArchive(SaveNote note) {
    _fakeNotes.remove(note);
    _fakeArchive.add(note);
    notifyListeners();
  }

  @override
  void moveNoteToTrash(SaveNote note) {
    _fakeNotes.remove(note);
    _fakeTrash.add(note);
    notifyListeners();
  }

  @override
  void restoreNoteFromTrash(SaveNote note) {
    _fakeTrash.remove(note);
    _fakeNotes.add(note);
    notifyListeners();
  }

  @override
  void restoreFromArchive(SaveNote note) {
    _fakeArchive.remove(note);
    _fakeNotes.add(note);
    notifyListeners();
  }

  @override
  void addNoteToFolder(SaveNote note, SaveFolder folder) {
    note.folderId = folder.key is int ? folder.key as int : 1;
    notifyListeners();
  }

  @override
  void removeNoteFromFolder(SaveNote note) {
    note.folderId = null;
    notifyListeners();
  }

  @override
  List<SaveNote> getNotesByFolder(int folderId) {
    return _fakeNotes.where((n) => n.folderId == folderId).toList();
  }
}

Widget _wrapWithProviders({
  required Widget child,
  required NoteProvider noteProvider,
  required ThemeProvider themeProvider,
  required NoteSettingsProvider settingsProvider,
  Locale locale = const Locale('ru'),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<NoteProvider>.value(value: noteProvider),
      ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ChangeNotifierProvider<NoteSettingsProvider>.value(
        value: settingsProvider,
      ),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  late Directory tempDir;
  late Box<SaveNote> notesBox;
  late Box<SaveNote> archiveBox;
  late Box<SaveNote> trashNotesBox;
  late Box<SaveFolder> foldersBox;
  late Box<SaveFolder> trashFoldersBox;

  setUpAll(() async {
    await initializeDateFormatting('ru');
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('inkflow_ui_test');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(SaveNoteAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(SaveFolderAdapter());
    }

    notesBox = await Hive.openBox<SaveNote>('notes');
    archiveBox = await Hive.openBox<SaveNote>('archive');
    trashNotesBox = await Hive.openBox<SaveNote>('trash_notes');
    foldersBox = await Hive.openBox<SaveFolder>('folders');
    trashFoldersBox = await Hive.openBox<SaveFolder>('trash_folders');
  });

  tearDownAll(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await notesBox.clear();
    await archiveBox.clear();
    await trashNotesBox.clear();
    await foldersBox.clear();
    await trashFoldersBox.clear();
  });

  group('SaveNote createdAt and updatedAt timestamps', () {
    test('createdAt is preserved and updatedAt changes on save', () async {
      final noteProvider = NoteProvider();
      final created = DateTime(2026, 11, 16, 14, 30);
      final note = SaveNote(
        title: 'Заметка 1',
        content: 'Текст',
        createdAt: created,
        updatedAt: created,
      );

      await noteProvider.addNote(note);
      expect(note.createdAt, created);

      await Future<void>.delayed(const Duration(milliseconds: 15));
      await noteProvider.saveNoteChanges(note);

      expect(note.createdAt, created);
      expect(note.updatedAt!.isAfter(created), isTrue);
    });

    test('updateNote preserves createdAt of existing note', () async {
      final noteProvider = NoteProvider();
      final created = DateTime(2026, 11, 10, 8, 0);
      final initial = SaveNote(
        title: 'Старое название',
        content: 'Старый текст',
        createdAt: created,
        updatedAt: created,
      );
      await noteProvider.addNote(initial);

      final updated = SaveNote(
        title: 'Новое название',
        content: 'Новый текст',
        createdAt: DateTime(2026, 11, 20, 10, 0),
      );

      await noteProvider.updateNote(initial, updated);

      expect(initial.createdAt, created);
      expect(initial.title, 'Новое название');
      expect(initial.updatedAt!.isAfter(created), isTrue);
    });

    testWidgets('formatNoteDateTime formats Russian date and time correctly', (
      tester,
    ) async {
      final dateTime = DateTime(2026, 11, 16, 14, 30);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              final formatted = formatNoteDateTime(context, dateTime);
              expect(formatted, '16 ноября 2026, 14:30');
              final timeOnly = formatNoteTime(context, dateTime);
              expect(timeOnly, '14:30');
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('NoteCard UI and Creation Date', () {
    testWidgets(
      'displays creation date under title with user selected font and updates reactively',
      (tester) async {
        final noteProvider = FakeNoteProvider();
        final themeProvider = ThemeProvider();
        final settingsProvider = NoteSettingsProvider();
        final created = DateTime(2026, 11, 16, 14, 30);

        final note = SaveNote(
          title: 'Моя заметка',
          content: 'Содержимое заметки',
          createdAt: created,
          updatedAt: created,
        );
        await noteProvider.addNote(note);

        await tester.pumpWidget(
          _wrapWithProviders(
            noteProvider: noteProvider,
            themeProvider: themeProvider,
            settingsProvider: settingsProvider,
            child: Scaffold(
              body: NoteCard(note: note, noteProvider: noteProvider),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Моя заметка'), findsOneWidget);
        expect(find.text('Создано: 16 ноября 2026, 14:30'), findsOneWidget);

        var dateTextWidget = tester.widget<Text>(
          find.text('Создано: 16 ноября 2026, 14:30'),
        );
        expect(dateTextWidget.style?.fontFamily, themeProvider.fontFamily);
        expect(dateTextWidget.style?.fontSize, 11);

        // Switch to Nunito
        await themeProvider.setFontFamily(ThemeProvider.fontNunito);
        await tester.pump();
        dateTextWidget = tester.widget<Text>(
          find.text('Создано: 16 ноября 2026, 14:30'),
        );
        expect(dateTextWidget.style?.fontFamily, ThemeProvider.fontNunito);

        // Switch to Jura
        await themeProvider.setFontFamily(ThemeProvider.fontJura);
        await tester.pump();
        dateTextWidget = tester.widget<Text>(
          find.text('Создано: 16 ноября 2026, 14:30'),
        );
        expect(dateTextWidget.style?.fontFamily, ThemeProvider.fontJura);

        // Switch to Oswald
        await themeProvider.setFontFamily(ThemeProvider.fontOswald);
        await tester.pump();
        dateTextWidget = tester.widget<Text>(
          find.text('Создано: 16 ноября 2026, 14:30'),
        );
        expect(dateTextWidget.style?.fontFamily, ThemeProvider.fontOswald);
      },
    );

    testWidgets('fits on narrow screens without overflow errors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(200, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final noteProvider = FakeNoteProvider();
      final themeProvider = ThemeProvider();
      final settingsProvider = NoteSettingsProvider();
      final note = SaveNote(
        title: 'Очень длинное название заметки для проверки переносов',
        content: 'Содержимое тестовой заметки',
        createdAt: DateTime(2026, 11, 16, 14, 30),
      );
      await noteProvider.addNote(note);

      await tester.pumpWidget(
        _wrapWithProviders(
          noteProvider: noteProvider,
          themeProvider: themeProvider,
          settingsProvider: settingsProvider,
          child: Scaffold(
            body: SizedBox(
              width: 140,
              height: 140,
              child: NoteCard(note: note, noteProvider: noteProvider),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('Desktop and Mobile Context Menu Gestures', () {
    testWidgets('desktop right click opens context menu at pointer', (
      tester,
    ) async {
      final noteProvider = FakeNoteProvider();
      final themeProvider = ThemeProvider();
      final settingsProvider = NoteSettingsProvider();
      final note = SaveNote(
        title: 'Контекстное меню',
        content: 'Текст',
        createdAt: DateTime(2026, 11, 16, 14, 30),
      );
      await noteProvider.addNote(note);

      await tester.pumpWidget(
        _wrapWithProviders(
          noteProvider: noteProvider,
          themeProvider: themeProvider,
          settingsProvider: settingsProvider,
          child: Scaffold(
            body: NoteCard(note: note, noteProvider: noteProvider),
          ),
        ),
      );
      await tester.pump();

      final cardFinder = find.byType(NoteCard);
      await tester.tap(cardFinder, buttons: kSecondaryMouseButton);
      await tester.pump();

      expect(find.text('Редактировать'), findsOneWidget);
      expect(find.text('Архивировать'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget);
    });

    testWidgets('desktop mouse long press does NOT open mobile menu dialog', (
      tester,
    ) async {
      final noteProvider = FakeNoteProvider();
      final themeProvider = ThemeProvider();
      final settingsProvider = NoteSettingsProvider();
      final note = SaveNote(
        title: 'Долгое нажатие мышью',
        content: 'Текст',
        createdAt: DateTime(2026, 11, 16, 14, 30),
      );
      await noteProvider.addNote(note);

      await tester.pumpWidget(
        _wrapWithProviders(
          noteProvider: noteProvider,
          themeProvider: themeProvider,
          settingsProvider: settingsProvider,
          child: Scaffold(
            body: NoteCard(note: note, noteProvider: noteProvider),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(NoteCard)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(seconds: 1));
      await gesture.up();
      await tester.pump();

      expect(find.text('Выберите вариант'), findsNothing);
    });

    testWidgets('touch long press opens mobile options dialog', (tester) async {
      final noteProvider = FakeNoteProvider();
      final themeProvider = ThemeProvider();
      final settingsProvider = NoteSettingsProvider();
      final note = SaveNote(
        title: 'Сенсорное нажатие',
        content: 'Текст',
        createdAt: DateTime(2026, 11, 16, 14, 30),
      );
      await noteProvider.addNote(note);

      await tester.pumpWidget(
        _wrapWithProviders(
          noteProvider: noteProvider,
          themeProvider: themeProvider,
          settingsProvider: settingsProvider,
          child: Scaffold(
            body: NoteCard(note: note, noteProvider: noteProvider),
          ),
        ),
      );
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(NoteCard)),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump();

      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.macOS ||
              defaultTargetPlatform == TargetPlatform.linux)) {
        // Desktop platforms suppress mobile long-press dialog
      } else {
        expect(find.text('Выберите вариант'), findsOneWidget);
      }
    });
  });

  group('Editor AutoSave Status Indicator and Timestamps', () {
    testWidgets('new note shows "Новая заметка" and creation date in header', (
      tester,
    ) async {
      final noteProvider = FakeNoteProvider();
      final themeProvider = ThemeProvider();
      final settingsProvider = NoteSettingsProvider();

      await tester.pumpWidget(
        _wrapWithProviders(
          noteProvider: noteProvider,
          themeProvider: themeProvider,
          settingsProvider: settingsProvider,
          child: const CreateNoteScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Новая заметка'), findsOneWidget);
      expect(find.textContaining('Создано:'), findsOneWidget);

      var statusText = tester.widget<Text>(find.text('Новая заметка'));
      expect(statusText.style?.fontFamily, themeProvider.fontFamily);

      // Verify reactive font update in editor
      await themeProvider.setFontFamily(ThemeProvider.fontNunito);
      await tester.pump();
      statusText = tester.widget<Text>(find.text('Новая заметка'));
      expect(statusText.style?.fontFamily, ThemeProvider.fontNunito);

      await themeProvider.setFontFamily(ThemeProvider.fontJura);
      await tester.pump();
      statusText = tester.widget<Text>(find.text('Новая заметка'));
      expect(statusText.style?.fontFamily, ThemeProvider.fontJura);
    });

    testWidgets('typing transitions status to "Есть несохранённые изменения"', (
      tester,
    ) async {
      final noteProvider = FakeNoteProvider();
      final themeProvider = ThemeProvider();
      final settingsProvider = NoteSettingsProvider();

      await tester.pumpWidget(
        _wrapWithProviders(
          noteProvider: noteProvider,
          themeProvider: themeProvider,
          settingsProvider: settingsProvider,
          child: const CreateNoteScreen(),
        ),
      );
      await tester.pump();

      final titleField = find.byType(TextField);
      await tester.enterText(titleField, 'Заметка с изменениями');
      await tester.pump();

      expect(find.text('Есть несохранённые изменения'), findsOneWidget);
    });

    testWidgets(
      'after debounce delay, note is saved and shows "Сохранено в HH:mm"',
      (tester) async {
        final noteProvider = FakeNoteProvider();
        final themeProvider = ThemeProvider();
        final settingsProvider = NoteSettingsProvider();

        await tester.pumpWidget(
          _wrapWithProviders(
            noteProvider: noteProvider,
            themeProvider: themeProvider,
            settingsProvider: settingsProvider,
            child: const CreateNoteScreen(),
          ),
        );
        await tester.pump();

        final titleField = find.byType(TextField);
        await tester.enterText(titleField, 'Автосохранённая заметка');
        await tester.pump();

        expect(find.text('Есть несохранённые изменения'), findsOneWidget);

        // Advance beyond debounce delay (600ms)
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump();

        expect(find.textContaining('Сохранено в'), findsOneWidget);
        expect(noteProvider.notes.length, 1);
        expect(noteProvider.notes.first.title, 'Автосохранённая заметка');
      },
    );

    testWidgets('existing note shows "Сохранено в HH:mm" on open', (
      tester,
    ) async {
      final noteProvider = FakeNoteProvider();
      final themeProvider = ThemeProvider();
      final settingsProvider = NoteSettingsProvider();
      final created = DateTime(2026, 11, 16, 10, 0);
      final updated = DateTime(2026, 11, 16, 19, 41);

      final note = SaveNote(
        title: 'Существующая',
        content: 'Текст',
        createdAt: created,
        updatedAt: updated,
      );
      await noteProvider.addNote(note);

      await tester.pumpWidget(
        _wrapWithProviders(
          noteProvider: noteProvider,
          themeProvider: themeProvider,
          settingsProvider: settingsProvider,
          child: CreateNoteScreen(note: note),
        ),
      );
      await tester.pump();

      expect(find.text('Сохранено в 19:41'), findsOneWidget);
      expect(find.text('Создано: 16 ноября 2026, 10:00'), findsOneWidget);
    });
  });
}
