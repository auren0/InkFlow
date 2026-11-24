import 'package:flutter/material.dart';
import 'package:inkflow/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { light, dark, oled }

class ThemeProvider extends ChangeNotifier {
  static const String themeModeKey = 'appTheme';
  static const String primaryColorKey = 'primaryColor';
  static const String fontFamilyKey = 'appFontFamily';
  static const String boldTextKey = 'appBoldText';
  static const String languageKey = 'appLanguage';

  static const _themeModeKey = themeModeKey;
  static const _primaryColorKey = primaryColorKey;
  static const _fontFamilyKey = fontFamilyKey;
  static const _boldTextKey = boldTextKey;
  static const _languageKey = languageKey;

  static const String fontJura = 'Jura';
  static const String fontOswald = 'Oswald';
  static const String fontNunito = 'Nunito';

  AppTheme _appTheme = AppTheme.dark;
  Color _primaryColor = Colors.yellow;
  String _fontFamily = fontOswald;
  bool _boldText = false;
  AppLanguage _language = AppLanguage.ru;

  AppTheme get appTheme => _appTheme;

  bool get isDark => _appTheme != AppTheme.light;

  bool get isOled => _appTheme == AppTheme.oled;

  Color get primaryColor => _primaryColor;

  String get fontFamily => _fontFamily;

  bool get boldText => _boldText;

  AppLanguage get language => _language;

  Locale get locale => Locale(_language.code);

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

    _fontFamily = prefs.getString(_fontFamilyKey) ?? fontOswald;
    _boldText = prefs.getBool(_boldTextKey) ?? false;
    _language = AppLanguage.fromCode(prefs.getString(_languageKey));
    AppLocalizations.currentLanguage = _language;

    notifyListeners();
  }

  Future<void> setFontFamily(String family) async {
    if (_fontFamily == family) return;

    _fontFamily = family;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, family);
  }

  Future<void> setBoldText(bool value) async {
    if (_boldText == value) return;

    _boldText = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_boldTextKey, value);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;

    _language = language;
    AppLocalizations.currentLanguage = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.code);
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

  /// Applies the known portable theme preferences from a validated backup.
  ///
  /// Only values that can be parsed and that belong to a supported option are
  /// accepted; anything else is ignored.
  Future<void> applyPortableSettings(Map<String, Object?> settings) async {
    final prefs = await SharedPreferences.getInstance();

    final themeName = settings[themeModeKey];
    if (themeName is String) {
      final theme = AppTheme.values.firstWhere(
        (candidate) => candidate.name == themeName,
        orElse: () => AppTheme.dark,
      );
      _appTheme = theme;
      await prefs.setString(themeModeKey, theme.name);
    }

    final colorValue = settings[primaryColorKey];
    if (colorValue is int) {
      _primaryColor = Color(colorValue);
      await prefs.setInt(primaryColorKey, colorValue);
    }

    final font = settings[fontFamilyKey];
    if (font is String &&
        (font == fontJura || font == fontOswald || font == fontNunito)) {
      _fontFamily = font;
      await prefs.setString(fontFamilyKey, font);
    }

    final bold = settings[boldTextKey];
    if (bold is bool) {
      _boldText = bold;
      await prefs.setBool(boldTextKey, bold);
    }

    final languageCode = settings[languageKey];
    if (languageCode is String) {
      _language = AppLanguage.fromCode(languageCode);
      AppLocalizations.currentLanguage = _language;
      await prefs.setString(languageKey, _language.code);
    }

    notifyListeners();
  }
}
