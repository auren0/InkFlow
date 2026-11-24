import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Portable note-list preferences that survive restarts and are included in
/// backups. Kept separate from [ThemeProvider] because they describe note
/// content presentation rather than the app theme.
class NoteSettingsProvider extends ChangeNotifier {
  static const String groupByDateKey = 'notesGroupByDate';
  static const String sortOrderKey = 'notesSortOrder';

  bool _groupByDate = false;
  String _sortOrder = 'newest';
  bool _initialized = false;

  bool get groupByDate => _groupByDate;

  /// `newest` is the only order exposed today and is the default. It is stored
  /// so future sort options (and restored backups) do not lose the choice.
  String get sortOrder => _sortOrder;

  NoteSettingsProvider() {
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _groupByDate = prefs.getBool(groupByDateKey) ?? false;
    _sortOrder = prefs.getString(sortOrderKey) ?? 'newest';
    _initialized = true;
    notifyListeners();
  }

  Future<void> setGroupByDate(bool value) async {
    if (_groupByDate == value) return;

    _groupByDate = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(groupByDateKey, value);
  }

  /// Applies only the known, portable keys from a backup. Unknown values are
  /// ignored instead of being written into preferences.
  Future<void> applyPortableSettings(Map<String, Object?> settings) async {
    final prefs = await SharedPreferences.getInstance();

    final grouped = settings[groupByDateKey];
    if (grouped is bool) {
      _groupByDate = grouped;
      await prefs.setBool(groupByDateKey, grouped);
    }

    final order = settings[sortOrderKey];
    if (order is String && order == 'newest') {
      _sortOrder = order;
      await prefs.setString(sortOrderKey, order);
    }

    _initialized = true;
    notifyListeners();
  }

  @visibleForTesting
  bool get isInitialized => _initialized;
}
