import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/update_provider.dart';
import 'package:inkflow/screens/settings_screen.dart';
import 'package:inkflow/shared_preferences/note_settings_provider.dart';
import 'package:inkflow/shared_preferences/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the settings screen with a simulated 48 px Android navigation bar.
Future<void> _pumpSettings(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(bottom: 48);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NoteSettingsProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('ru'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('settings list leaves room for the system navigation bar', (
    tester,
  ) async {
    await _pumpSettings(tester);

    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.padding, const EdgeInsets.fromLTRB(16, 16, 16, 64));

    // The last section must be scrollable fully above the navigation bar.
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    final updateTile = tester.getRect(find.text('Обновления'));
    expect(updateTile.bottom, lessThanOrEqualTo(600 - 48));
  });

  testWidgets('bottom sheet content stays above the navigation bar', (
    tester,
  ) async {
    await _pumpSettings(tester);

    await tester.scrollUntilVisible(find.text('Шрифт').first, 300);
    await tester.tap(find.text('Шрифт').first);
    await tester.pumpAndSettle();

    final lastFont = tester.getRect(find.text('Nunito'));
    expect(lastFont.bottom, lessThanOrEqualTo(600 - 48));
  });
}
