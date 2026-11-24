import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/update_provider.dart';
import 'package:inkflow/services/debouncer.dart';
import 'package:inkflow/services/note_content.dart';
import 'package:inkflow/services/update_service.dart';
import 'package:inkflow/theme/app_color_scheme.dart';
import 'package:inkflow/theme/app_text_theme.dart';
import 'package:inkflow/widgets/note_format_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUpdateService extends UpdateService {
  _FakeUpdateService(this.update);

  final UpdateInfo update;

  @override
  Future<String> getCurrentVersion() async => '1.0.0';

  @override
  Future<UpdateInfo?> checkForUpdate() async => update;

  @override
  Future<void> openDownload(UpdateInfo update) async {}

  @override
  Future<void> openReleasePage(UpdateInfo update) async {}
}

void main() {
  group('NoteContent', () {
    test('wraps legacy plain-text notes without losing data', () {
      const plain = 'Первая строка\nВторая строка';

      final document = NoteContent.parse(plain);

      expect(document.toPlainText().trim(), plain);
      expect(NoteContent.plainText(plain), plain);
      expect(NoteContent.hasText(plain), isTrue);
      expect(NoteContent.hasText(''), isFalse);
    });

    test('round-trips bold, italic, underline and strikethrough', () {
      final document = Document.fromJson([
        {
          'insert': 'Bold',
          'attributes': {'bold': true},
        },
        {
          'insert': ' Italic',
          'attributes': {'italic': true},
        },
        {
          'insert': ' Underline',
          'attributes': {'underline': true},
        },
        {
          'insert': ' Strike',
          'attributes': {'strike': true},
        },
        {'insert': '\n'},
      ]);

      final encoded = NoteContent.encode(document);
      final restored = NoteContent.parse(encoded);

      final attributeKeys = <String>{};
      for (final operation in restored.toDelta().toJson()) {
        if (operation['attributes'] is Map) {
          attributeKeys.addAll(
            (operation['attributes'] as Map).keys.cast<String>(),
          );
        }
      }

      expect(
        attributeKeys,
        containsAll(['bold', 'italic', 'underline', 'strike']),
      );
      expect(NoteContent.plainText(encoded), 'Bold Italic Underline Strike');
    });

    test('preserves checked and unchecked TODO state', () {
      final document = Document.fromJson([
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

      final encoded = NoteContent.encode(document);
      final restored = NoteContent.parse(encoded);

      final lists = restored
          .toDelta()
          .toJson()
          .whereType<Map>()
          .map((operation) => (operation['attributes'] as Map?)?['list'])
          .whereType<String>()
          .toList();

      expect(lists, containsAll(['checked', 'unchecked']));
      expect(NoteContent.plainText(encoded), 'Done\nTodo');
    });

    test('does not interpret arbitrary JSON-looking text as a Delta', () {
      const raw = '[not a delta]';

      expect(NoteContent.plainText(raw), raw);
      expect(NoteContent.parse(raw).toPlainText().trim(), raw);
    });

    test('never shows raw Delta JSON in a preview', () {
      final document = Document.fromJson([
        {
          'insert': 'Visible text',
          'attributes': {'bold': true},
        },
        {'insert': '\n'},
      ]);

      final preview = NoteContent.plainText(NoteContent.encode(document));

      expect(preview, 'Visible text');
      expect(preview, isNot(contains('insert')));
    });
  });

  group('Quill editing', () {
    test('applies and removes inline formatting', () {
      final controller = QuillController(
        document: Document.fromJson([
          {'insert': 'Hello\n'},
        ]),
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      );

      controller.formatSelection(Attribute.bold);
      expect(
        controller.getSelectionStyle().attributes.containsKey('bold'),
        isTrue,
      );

      controller.formatSelection(Attribute.clone(Attribute.bold, null));
      expect(
        controller.getSelectionStyle().attributes.containsKey('bold'),
        isFalse,
      );
    });

    test('toggles a TODO checkbox state without changing the text', () {
      final controller = QuillController(
        document: Document.fromJson([
          {'insert': 'Task\n'},
        ]),
        selection: const TextSelection(baseOffset: 0, extentOffset: 4),
      );

      controller.formatSelection(Attribute.unchecked);
      expect(
        controller.getSelectionStyle().attributes['list']?.value,
        'unchecked',
      );

      controller.formatSelection(Attribute.checked);
      expect(
        controller.getSelectionStyle().attributes['list']?.value,
        'checked',
      );
      expect(controller.document.toPlainText().trim(), 'Task');
    });

    test('supports undo and redo', () {
      final controller = QuillController.basic();

      controller.replaceText(
        0,
        0,
        'Hello',
        const TextSelection.collapsed(offset: 5),
      );

      expect(controller.document.toPlainText().trim(), 'Hello');
      expect(controller.hasUndo, isTrue);

      controller.undo();
      expect(controller.document.toPlainText().trim(), isEmpty);

      controller.redo();
      expect(controller.document.toPlainText().trim(), 'Hello');
    });
  });

  group('NoteFormatToolbar', () {
    testWidgets('toggles bold for the next typed text', (tester) async {
      final controller = QuillController.basic();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            bottomNavigationBar: NoteFormatToolbar(
              controller: controller,
              focusNode: focusNode,
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(FluentIcons.text_bold_24_regular));
      await tester.pump();
      expect(controller.toggledStyle.attributes['bold']?.value, isTrue);

      await tester.tap(find.byIcon(FluentIcons.text_bold_24_regular));
      await tester.pump();
      expect(controller.toggledStyle.attributes['bold']?.value, isNot(isTrue));

      focusNode.dispose();
      controller.dispose();
    });
  });

  group('App color scheme', () {
    test('keeps the user-selected white color instead of a cyan tint', () {
      final scheme = buildAppColorScheme(
        seedColor: Colors.white,
        brightness: Brightness.dark,
      );

      expect(scheme.primary, Colors.white);
      expect(scheme.onPrimary, Colors.black);
    });

    test('darkens a too-light color on a light theme for readability', () {
      final scheme = buildAppColorScheme(
        seedColor: Colors.white,
        brightness: Brightness.light,
      );

      expect(scheme.primary, isNot(Colors.white));
      expect(scheme.onPrimary, Colors.white);
    });

    test('keeps a custom interface color literally', () {
      const custom = Color(0xFF16A34A);
      final scheme = buildAppColorScheme(
        seedColor: custom,
        brightness: Brightness.light,
      );

      expect(scheme.primary, custom);
      expect(scheme.onPrimary, Colors.white);
    });

    test('switch hover thumb does not use the cyan primary container', () {
      final scheme = buildAppColorScheme(
        seedColor: Colors.white,
        brightness: Brightness.dark,
      );
      final switchTheme = buildAppSwitchTheme(scheme);

      final hoveredThumb = switchTheme.thumbColor!.resolve({
        WidgetState.selected,
        WidgetState.hovered,
      });

      expect(hoveredThumb, isNot(scheme.primaryContainer));
      expect(hoveredThumb, Color.lerp(scheme.onPrimary, scheme.primary, 0.3));
    });
  });

  group('App text theme', () {
    test(
      'applies bold to styles with a null font weight without asserting',
      () {
        const base = TextTheme(
          bodyMedium: TextStyle(),
          titleLarge: TextStyle(fontWeight: FontWeight.w500),
        );

        final theme = applyAppFont(base, family: 'Oswald', bold: true);

        expect(theme.bodyMedium!.fontWeight, FontWeight.w700);
        expect(theme.titleLarge!.fontWeight, FontWeight.w800);
        expect(theme.bodyMedium!.fontFamily, 'Oswald');
      },
    );

    test('keeps regular weights when bold is disabled', () {
      const base = TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.w500),
      );

      final theme = applyAppFont(base, family: 'Nunito', bold: false);

      expect(theme.titleLarge!.fontWeight, FontWeight.w500);
      expect(theme.titleLarge!.fontFamily, 'Nunito');
    });
  });

  group('UpdateProvider', () {
    test('does not show the startup dialog again after Later', () async {
      SharedPreferences.setMockInitialValues({});

      const update = UpdateInfo(
        version: '1.2.0',
        releaseNotes: 'Fixes',
        downloadUrl: 'https://example.com/InkFlow-Setup.exe',
        releasePageUrl: 'https://github.com/auren0/InkFlow/releases',
      );
      final service = _FakeUpdateService(update);

      final firstLaunch = UpdateProvider(service: service);
      await firstLaunch.initialize();

      expect(firstLaunch.hasUpdate, isTrue);
      expect(firstLaunch.shouldShowStartupDialog, isTrue);

      await firstLaunch.dismissUpdate();

      // Simulate an app restart: the same version is found, but it was
      // dismissed earlier and must not show the startup dialog again.
      final afterRestart = UpdateProvider(service: service);
      await afterRestart.initialize();

      expect(afterRestart.update?.version, '1.2.0');
      expect(afterRestart.shouldShowStartupDialog, isFalse);
    });
  });

  group('Debouncer (auto-save)', () {
    testWidgets('fires only once after the last change', (tester) async {
      final debouncer = Debouncer(const Duration(milliseconds: 600));
      var saves = 0;

      debouncer.schedule(() => saves++);
      await tester.pump(const Duration(milliseconds: 300));

      debouncer.schedule(() => saves++);
      await tester.pump(const Duration(milliseconds: 300));

      expect(saves, 0);

      await tester.pump(const Duration(milliseconds: 400));
      expect(saves, 1);

      debouncer.dispose();
    });

    testWidgets('cancel prevents a pending save', (tester) async {
      final debouncer = Debouncer(const Duration(milliseconds: 600));
      var saves = 0;

      debouncer.schedule(() => saves++);
      debouncer.cancel();

      await tester.pump(const Duration(milliseconds: 700));
      expect(saves, 0);

      debouncer.dispose();
    });
  });
}
