import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/providers/update_provider.dart';
import 'package:inkflow/services/semantic_version.dart';
import 'package:inkflow/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ThrowingUpdateService extends UpdateService {
  @override
  Future<String> getCurrentVersion() async => '1.3.0';

  @override
  Future<UpdateInfo?> checkForUpdate() async {
    throw const UpdateCheckException('Не удалось подключиться к GitHub');
  }
}

class _NullUpdateService extends UpdateService {
  @override
  Future<String> getCurrentVersion() async => '1.3.0';

  @override
  Future<UpdateInfo?> checkForUpdate() async => null;
}

void main() {
  group('Semantic version comparison', () {
    test('1.3.0 and 1.3.0 does not require an update', () {
      expect(isUpdateAvailable(current: '1.3.0', latest: '1.3.0'), isFalse);
      expect(isUpdateAvailable(current: '1.3.0', latest: 'v1.3.0'), isFalse);
    });

    test('1.3.0 and 1.3.1 is an available update', () {
      expect(isUpdateAvailable(current: '1.3.0', latest: 'v1.3.1'), isTrue);
    });

    test('1.10.0 is not older than 1.9.0', () {
      expect(isUpdateAvailable(current: '1.10.0', latest: '1.9.0'), isFalse);
      expect(isUpdateAvailable(current: '1.9.0', latest: '1.10.0'), isTrue);
    });

    test('1.4.0 and 2.0.0 use numeric, not string, ordering', () {
      expect(isUpdateAvailable(current: '1.4.0', latest: '2.0.0'), isTrue);
      expect(isUpdateAvailable(current: '2.0.0', latest: '1.4.0'), isFalse);
    });

    test('pre-releases are older than the matching release', () {
      expect(compareSemanticVersions('1.4.0-beta.1', '1.4.0'), lessThan(0));
      expect(compareSemanticVersions('1.4.0', '1.4.0-beta.1'), greaterThan(0));
      expect(
        isUpdateAvailable(current: '1.4.0-beta.2', latest: '1.4.0'),
        isTrue,
      );
      expect(
        isUpdateAvailable(current: '1.4.0', latest: '1.4.0-beta.2'),
        isFalse,
      );
    });

    test('build metadata does not affect precedence', () {
      expect(compareSemanticVersions('1.3.0+42', 'v1.3.0'), 0);
      expect(isUpdateAvailable(current: '1.3.0+7', latest: '1.3.0'), isFalse);
    });

    test('invalid versions throw instead of pretending to be current', () {
      expect(
        () => compareSemanticVersions('release-latest', '1.3.0'),
        throwsFormatException,
      );
    });
  });

  group('UpdateProvider error handling', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AppLocalizations.currentLanguage = AppLanguage.ru;
    });

    test(
      'a failed check shows an error and is not reported as up to date',
      () async {
        final provider = UpdateProvider(service: _ThrowingUpdateService());

        await provider.checkForUpdates();

        expect(provider.error, isNotNull);
        expect(provider.error, contains('GitHub'));
        expect(provider.hasUpdate, isFalse);
        expect(provider.isUpToDate, isFalse);
      },
    );

    test(
      'a successful equal-version check is reported as up to date',
      () async {
        final provider = UpdateProvider(service: _NullUpdateService());

        await provider.checkForUpdates();

        expect(provider.error, isNull);
        expect(provider.hasUpdate, isFalse);
        expect(provider.isUpToDate, isTrue);
      },
    );
  });
}
