import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:note_app/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Хранит информацию о доступном обновлении, чтобы её можно было показать
/// при запуске приложения и в настройках.
class UpdateProvider extends ChangeNotifier {
  UpdateProvider({UpdateService? service})
    : _service = service ?? UpdateService();

  static const String _dismissedVersionKey = 'dismissedUpdateVersion';

  final UpdateService _service;

  UpdateInfo? _update;
  String _currentVersion = '';
  String? _error;
  String? _dismissedVersion;
  bool _checking = false;
  bool _initialized = false;

  UpdateInfo? get update => _update;

  bool get hasUpdate => _update != null;

  String get currentVersion => _currentVersion;

  String? get error => _error;

  bool get isChecking => _checking;

  /// Нужно ли автоматически показывать окно обновления при запуске.
  bool get shouldShowStartupDialog =>
      _update != null && _update!.version != _dismissedVersion;

  /// Загружает сохранённые настройки и проверяет обновления при запуске.
  Future<void> initialize() async {
    if (!Platform.isWindows || _initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _dismissedVersion = prefs.getString(_dismissedVersionKey);

    await checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    if (!Platform.isWindows || _checking) return;

    _checking = true;
    _error = null;
    notifyListeners();

    try {
      _currentVersion = await _service.getCurrentVersion();
      _update = await _service.checkForUpdate();
    } catch (e) {
      _error = e.toString();
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  /// Запоминает версию, окно с которой пользователь закрыл. При следующем
  /// запуске оно уже не появится само, но останется в настройках.
  Future<void> dismissUpdate() async {
    final version = _update?.version;
    if (version == null) return;

    _dismissedVersion = version;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedVersionKey, version);
  }

  Future<void> openDownload() async {
    final update = _update;
    if (update == null) return;
    await _service.openDownload(update);
  }

  Future<void> openReleasePage() async {
    final update = _update;
    if (update == null) return;
    await _service.openReleasePage(update);
  }
}
