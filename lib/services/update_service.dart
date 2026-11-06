import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

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

  /// Проверяет последний релиз на GitHub и возвращает его, если версия новее
  /// установленной. На других платформах, кроме Windows, возвращает null.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!Platform.isWindows) return null;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();

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

    final downloadUrl = installer['browser_download_url'] as String?;
    if (downloadUrl == null || downloadUrl.isEmpty) {
      throw Exception('В последнем релизе нет установщика .exe');
    }

    return UpdateInfo(
      version: version,
      releaseNotes: (data['body'] as String? ?? '').trim(),
      downloadUrl: downloadUrl,
      releasePageUrl: (data['html_url'] as String? ?? '').trim(),
    );
  }

  /// Скачивает установщик во временную папку.
  Future<File> downloadUpdate(
    UpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = 'InkFlow-Setup-${update.version}.exe';
    final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');

    if (await file.exists()) {
      await file.delete();
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(update.downloadUrl));
      request.headers['User-Agent'] = 'InkFlow';

      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception(
          'Не удалось скачать установщик (код ${response.statusCode})',
        );
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;
      final sink = file.openWrite();

      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            onProgress?.call(receivedBytes / totalBytes);
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      client.close();
    }

    return file;
  }

  /// Запускает установщик в тихом режиме и закрывает приложение.
  Future<void> installUpdate(File installer) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Обновление доступно только на Windows');
    }

    await Process.start(installer.path, const [
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
    ], mode: ProcessStartMode.detached);

    exit(0);
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
