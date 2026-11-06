import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, dark, oled }

class ThemeProvider extends ChangeNotifier {
  static const _themeModeKey = 'appTheme';
  static const _primaryColorKey = 'primaryColor';

  AppTheme _appTheme = AppTheme.dark;
  Color _primaryColor = Colors.yellow;

  AppTheme get appTheme => _appTheme;

  bool get isDark => _appTheme != AppTheme.light;

  bool get isOled => _appTheme == AppTheme.oled;

  Color get primaryColor => _primaryColor;

  /// Цвет текста и иконок, которые находятся на основном цвете.
  Color get onPrimaryColor =>
      _primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  ThemeMode get currentTheme =>
      _appTheme == AppTheme.light ? ThemeMode.light : ThemeMode.dark;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString(_themeModeKey);
    if (savedTheme != null) {
      _appTheme = AppTheme.values.firstWhere(
        (theme) => theme.name == savedTheme,
        orElse: () => AppTheme.dark,
      );
    } else {
      _appTheme = AppTheme.dark;
    }

    _primaryColor = Color(
      prefs.getInt(_primaryColorKey) ?? Colors.yellow.toARGB32(),
    );
    notifyListeners();
  }

  Future<void> setAppTheme(AppTheme theme) async {
    _appTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, theme.name);
    notifyListeners();
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_primaryColorKey, color.toARGB32());
    notifyListeners();
  }

  Future<void> resetPrimaryColor() => setPrimaryColor(Colors.yellow);
}
