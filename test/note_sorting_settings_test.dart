import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/hive_models/save_note.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/services/note_sorting.dart';
import 'package:inkflow/shared_preferences/note_settings_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

SaveNote _note(String title, DateTime createdAt) {
  return SaveNote(
    title: title,
    content: title,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Future<NoteSettingsProvider> _loadedSettingsProvider() async {
  final provider = NoteSettingsProvider();
  for (var i = 0; i < 100 && !provider.isInitialized; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  return provider;
}

void main() {
  group('Note sorting and grouping', () {
    test('new notes are sorted above older notes', () {
      final old = _note('old', DateTime(2026, 11, 14, 10));
      final middle = _note('middle', DateTime(2026, 11, 15, 10));
      final newest = _note('newest', DateTime(2026, 11, 16, 10));

      final sorted = NoteSorting.newestFirst([old, newest, middle]);

      expect(sorted.map((note) => note.title), ['newest', 'middle', 'old']);
    });

    test('equal creation times have a stable deterministic order', () {
      final time = DateTime(2026, 11, 16, 10);
      final notes = [_note('B', time), _note('A', time), _note('C', time)];

      final firstRun = NoteSorting.newestFirst(notes).map((n) => n.title);
      final secondRun = NoteSorting.newestFirst(
        notes.reversed,
      ).map((n) => n.title);

      expect(firstRun, secondRun);
    });

    test(
      'grouping uses local dates, newest group first, without duplicates',
      () {
        final notes = [
          _note('16-a', DateTime(2026, 11, 16, 9)),
          _note('15-a', DateTime(2026, 11, 15, 9)),
          _note('16-b', DateTime(2026, 11, 16, 18)),
        ];

        final groups = NoteSorting.groupByLocalDate(notes);

        expect(groups.length, 2);
        expect(groups.first.date, DateTime(2026, 11, 16));
        expect(groups.first.notes.map((n) => n.title), ['16-b', '16-a']);
        expect(groups.last.date, DateTime(2026, 11, 15));

        final allTitles = groups
            .expand((group) => group.notes)
            .map((n) => n.title);
        expect(allTitles.length, notes.length);
        expect(allTitles.toSet().length, notes.length);
      },
    );

    testWidgets('date header is localized as "16 ноября 2026"', (tester) async {
      await initializeDateFormatting();

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
            builder: (context) => Scaffold(
              body: Text(formatNoteDateHeader(context, DateTime(2026, 11, 16))),
            ),
          ),
        ),
      );

      expect(find.text('16 ноября 2026'), findsOneWidget);
    });
  });

  group('NoteSettingsProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('grouping is disabled by default', () async {
      final provider = await _loadedSettingsProvider();

      expect(provider.groupByDate, isFalse);
    });

    test('turning grouping on updates listeners immediately', () async {
      final provider = await _loadedSettingsProvider();
      await provider.load();
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setGroupByDate(true);

      expect(provider.groupByDate, isTrue);
      expect(notifications, greaterThan(0));
    });

    test(
      'turning grouping off is persisted and restored after restart',
      () async {
        final first = await _loadedSettingsProvider();
        await first.setGroupByDate(true);

        final restarted = await _loadedSettingsProvider();
        expect(restarted.groupByDate, isTrue);

        await restarted.setGroupByDate(false);

        final restartedAgain = await _loadedSettingsProvider();
        expect(restartedAgain.groupByDate, isFalse);
      },
    );
  });
}
