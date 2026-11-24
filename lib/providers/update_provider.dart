import 'package:flutter/foundation.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:inkflow/services/update_service.dart';
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
  bool _lastCheckCompleted = false;

  UpdateInfo? get update => _update;

  bool get hasUpdate => _update != null;

  String get currentVersion => _currentVersion;

  String? get error => _error;

  bool get isChecking => _checking;

  /// True only when the last completed check succeeded and found no update.
  /// Never use this when [error] is set: a network failure is not proof that
  /// the installed version is current.
  bool get isUpToDate =>
      _lastCheckCompleted && !_checking && _error == null && _update == null;

  /// Нужно ли автоматически показывать окно обновления при запуске.
  bool get shouldShowStartupDialog =>
      _update != null && _update!.version != _dismissedVersion;

  /// Загружает сохранённые настройки и проверяет обновления при запуске.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _dismissedVersion = prefs.getString(_dismissedVersionKey);

    await checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    if (_checking) return;

    _checking = true;
    _error = null;
    _lastCheckCompleted = false;

    // Never keep a previous result visible while a new check is running or
    // after it failed. Otherwise an old release could be offered even though
    // the current version is already up to date.
    _update = null;
    notifyListeners();

    try {
      _currentVersion = await _service.getCurrentVersion();
      _update = await _service.checkForUpdate();
      _lastCheckCompleted = true;
    } catch (error) {
      _update = null;
      _error = _friendlyError(error);
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  String _friendlyError(Object error) {
    if (error is UpdateCheckException) return error.message;

    return AppLocalizations.translate('update.errorGeneric', {'error': error});
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
