import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

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

  /// Возвращает текущую версию приложения из `pubspec.yaml`.
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version.trim();
  }

  /// Проверяет последний релиз на GitHub и возвращает его, если версия новее
  /// установленной. На других платформах, кроме Windows, возвращает null.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!Platform.isWindows) return null;

    final currentVersion = await getCurrentVersion();

    final response = await http
        .get(
          Uri.parse(_latestReleaseUrl),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'InkFlow',
          },
        )
        .timeout(const Duration(seconds: 20));

    // Релизов ещё нет — обновляться некуда.
    if (response.statusCode == 404) return null;

    if (response.statusCode != 200) {
      throw Exception(
        'GitHub вернул код ${response.statusCode}. '
        'Попробуйте позже.',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String? ?? '').trim();
    final version = _normalizeVersion(tag);

    if (version.isEmpty || _compareVersions(version, currentVersion) <= 0) {
      return null;
    }

    final assets = (data['assets'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final installer = assets.firstWhere(
      (asset) =>
          (asset['name'] as String? ?? '').toLowerCase().endsWith('.exe'),
      orElse: () => const <String, dynamic>{},
    );

    final releasePageUrl = (data['html_url'] as String? ?? '').trim();
    final downloadUrl = (installer['browser_download_url'] as String? ?? '')
        .trim();

    return UpdateInfo(
      version: version,
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

  /// Открывает ссылку в системном браузере.
  Future<void> openUrl(String url) async {
    if (url.isEmpty) {
      throw Exception('Пустая ссылка');
    }

    if (Platform.isWindows) {
      await Process.start('rundll32', [
        'url.dll,FileProtocolHandler',
        url,
      ], mode: ProcessStartMode.detached);
      return;
    }

    if (Platform.isMacOS) {
      await Process.start('open', [url], mode: ProcessStartMode.detached);
      return;
    }

    if (Platform.isLinux) {
      await Process.start('xdg-open', [url], mode: ProcessStartMode.detached);
      return;
    }

    throw UnsupportedError(
      'Открытие ссылок не поддерживается на этой платформе',
    );
  }

  String _normalizeVersion(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('+')
        .first
        .split('-')
        .first
        .trim();
  }

  int _compareVersions(String a, String b) {
    final first = _versionParts(a);
    final second = _versionParts(b);
    final length = first.length > second.length ? first.length : second.length;

    for (var i = 0; i < length; i++) {
      final firstPart = i < first.length ? first[i] : 0;
      final secondPart = i < second.length ? second[i] : 0;
      if (firstPart != secondPart) {
        return firstPart.compareTo(secondPart);
      }
    }

    return 0;
  }

  List<int> _versionParts(String value) {
    return _normalizeVersion(value)
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'\D.*$'), '')) ?? 0)
        .toList();
  }
}
