import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/services/semantic_version.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// A user-facing update-check failure.
///
/// Keeping a dedicated exception type lets the provider show a clear message
/// instead of leaking `Exception: ...` internals into the UI.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Информация о доступном обновлении с GitHub Releases.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.releasePageUrl,
  });

  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final String releasePageUrl;
}

class UpdateService {
  static const String repository = 'auren0/InkFlow';
  static const String _latestReleaseUrl =
      'https://api.github.com/repos/$repository/releases/latest';
  static const String _releasesPageUrl =
      'https://github.com/$repository/releases/latest';

  /// Возвращает текущую версию приложения из `package_info_plus`.
  ///
  /// PackageInfo.version intentionally does not include the build number
  /// (`1.3.0+42` → `1.3.0`), so the release version and the platform build
  /// number can never be confused.
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version.trim();
  }

  /// Проверяет последний релиз на GitHub и возвращает его, если версия новее
  /// установленной.
  ///
  /// Returns `null` when the installed version is equal to or newer than the
  /// published one. Throws [UpdateCheckException] when the release cannot be
  /// checked or has an invalid version. A failed check is never reported as
  /// "you have the latest version".
  Future<UpdateInfo?> checkForUpdate() async {
    final SemanticVersion currentVersion;
    try {
      final rawCurrentVersion = await getCurrentVersion();
      final parsed = SemanticVersion.tryParse(rawCurrentVersion);
      if (parsed == null) {
        throw UpdateCheckException(
          AppLocalizations.translate('update.errorCurrentVersion', {
            'version': rawCurrentVersion,
          }),
        );
      }
      currentVersion = parsed;
    } on UpdateCheckException {
      rethrow;
    } catch (error) {
      throw UpdateCheckException(
        AppLocalizations.translate('update.errorCurrentVersionUnknown', {
          'error': error,
        }),
      );
    }

    final http.Response response;
    try {
      response = await http
          .get(
            Uri.parse(_latestReleaseUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'InkFlow',
            },
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw UpdateCheckException(
        AppLocalizations.translate('update.errorTimeout'),
      );
    } catch (error) {
      throw UpdateCheckException(
        AppLocalizations.translate('update.errorNetwork', {'error': error}),
      );
    }

    // Релизов ещё нет — обновляться некуда.
    if (response.statusCode == 404) return null;

    if (response.statusCode != 200) {
      throw UpdateCheckException(
        AppLocalizations.translate('update.errorStatus', {
          'code': response.statusCode,
        }),
      );
    }

    final Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('Release response is not an object');
      }
      data = decoded.cast<String, dynamic>();
    } catch (_) {
      throw UpdateCheckException(
        AppLocalizations.translate('update.errorInvalidRelease'),
      );
    }

    final tag = (data['tag_name'] as String? ?? '').trim();
    final latestVersion = SemanticVersion.tryParse(tag);
    if (latestVersion == null) {
      throw UpdateCheckException(
        AppLocalizations.translate('update.errorInvalidRelease'),
      );
    }

    // Equal versions (1.3.0 == v1.3.0) and installed versions newer than the
    // published release must not offer an update. Pre-release precedence and
    // build metadata are handled by SemanticVersion:
    //   1.3.0-beta < 1.3.0 < 1.3.1 < 1.4.0 < 1.10.0 < 2.0.0
    if (!latestVersion.isNewerThan(currentVersion)) {
      return null;
    }

    final assets = (data['assets'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((asset) => asset.cast<String, dynamic>())
        .toList();
    final installer = _findInstaller(assets);

    final releasePageUrl = (data['html_url'] as String? ?? '').trim();
    final downloadUrl = (installer['browser_download_url'] as String? ?? '')
        .trim();

    return UpdateInfo(
      version: latestVersion.toString(),
      releaseNotes: (data['body'] as String? ?? '').trim(),
      downloadUrl: downloadUrl,
      releasePageUrl: releasePageUrl.isEmpty
          ? _releasesPageUrl
          : releasePageUrl,
    );
  }

  /// Открывает страницу скачивания установщика в браузере.
  Future<void> openDownload(UpdateInfo update) async {
    final url = update.downloadUrl.isNotEmpty
        ? update.downloadUrl
        : update.releasePageUrl;
    await openUrl(url);
  }

  /// Открывает страницу релиза на GitHub в браузере.
  Future<void> openReleasePage(UpdateInfo update) async {
    await openUrl(update.releasePageUrl);
  }

  /// Открывает ссылку в системном браузере на любой платформе.
  Future<void> openUrl(String url) async {
    if (url.isEmpty) {
      throw Exception(AppLocalizations.translate('update.errorEmptyLink'));
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw Exception(AppLocalizations.translate('update.errorEmptyLink'));
    }

    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (!launched) {
      throw Exception(AppLocalizations.translate('update.errorUnsupported'));
    }
  }

  Map<String, dynamic> _findInstaller(List<Map<String, dynamic>> assets) {
    if (assets.isEmpty) return const <String, dynamic>{};

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const preferredApks = [
        'app-release.apk',
        'app-arm64-v8a-release.apk',
        'app-armeabi-v7a-release.apk',
        'app-x86_64-release.apk',
      ];

      for (final name in preferredApks) {
        final match = assets.firstWhere(
          (asset) => (asset['name'] as String? ?? '').toLowerCase() == name,
          orElse: () => const <String, dynamic>{},
        );
        if (match.isNotEmpty) return match;
      }
    }

    for (final suffix in _assetSuffixesForPlatform()) {
      final match = assets.firstWhere(
        (asset) =>
            (asset['name'] as String? ?? '').toLowerCase().endsWith(suffix),
        orElse: () => const <String, dynamic>{},
      );
      if (match.isNotEmpty) return match;
    }

    return const <String, dynamic>{};
  }

  List<String> _assetSuffixesForPlatform() {
    if (kIsWeb) return const [];

    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => const ['.exe'],
      TargetPlatform.android => const ['.apk'],
      TargetPlatform.macOS => const ['.dmg', '.zip'],
      TargetPlatform.linux => const ['.appimage', '.deb', '.tar.gz'],
      _ => const [],
    };
  }
}
