import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/update_provider.dart';
import 'package:inkflow/services/update_service.dart';
import 'package:inkflow/widgets/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeUpdateService extends UpdateService {
  @override
  Future<String> getCurrentVersion() async => '1.3.0';

  @override
  Future<UpdateInfo?> checkForUpdate() async => const UpdateInfo(
    version: '1.4.0',
    releaseNotes: 'Новые возможности и исправления',
    downloadUrl: 'https://example.com/InkFlow-Setup.exe',
    releasePageUrl: 'https://github.com/auren0/InkFlow/releases',
  );
}

Future<void> _openUpdateDialog(
  WidgetTester tester, {
  required Size surfaceSize,
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  final provider = UpdateProvider(service: _FakeUpdateService());
  await provider.checkForUpdates();

  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

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
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showUpdateAvailableDialog(
                context: context,
                updateProvider: provider,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('three update actions fit on a narrow screen without overflow', (
    tester,
  ) async {
    await _openUpdateDialog(
      tester,
      surfaceSize: const Size(320, 640),
      textScale: 1.6,
    );

    expect(find.text('Позже'), findsOneWidget);
    expect(find.text('Открыть на GitHub'), findsOneWidget);
    expect(find.text('Скачать обновление'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('three update actions stay on one row in a wide window', (
    tester,
  ) async {
    await _openUpdateDialog(tester, surfaceSize: const Size(1280, 800));

    expect(tester.takeException(), isNull);

    final laterY = tester.getCenter(find.text('Позже')).dy;
    expect(tester.getCenter(find.text('Открыть на GitHub')).dy, laterY);
    expect(tester.getCenter(find.text('Скачать обновление')).dy, laterY);
  });
}
