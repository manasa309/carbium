import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReaderMode { scroll, paged }

class SettingsProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _fontSizeKey = 'font_size';
  static const String _fontFamilyKey = 'font_family';
  static const String _readerModeKey = 'reader_mode';
  static const String _isSepiaKey = 'is_sepia';

  ThemeMode _themeMode = ThemeMode.system;
  double _fontSize = 18.0;
  String _fontFamily = 'Default';
  ReaderMode _readerMode = ReaderMode.scroll;
  bool _isSepia = false;

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  String get fontFamily => _fontFamily;
  ReaderMode get readerMode => _readerMode;
  bool get isSepia => _isSepia;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    _fontSize = prefs.getDouble(_fontSizeKey) ?? 18.0;
    _fontFamily = prefs.getString(_fontFamilyKey) ?? 'Default';
    
    final modeIndex = prefs.getInt(_readerModeKey) ?? 0;
    _readerMode = ReaderMode.values[modeIndex];
    
    _isSepia = prefs.getBool(_isSepiaKey) ?? false;
    
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _isSepia = false; // Disable sepia if standard theme is chosen
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    await prefs.setBool(_isSepiaKey, false);
  }
  
  Future<void> setSepia(bool enable) async {
    _isSepia = enable;
    if (enable) {
      _themeMode = ThemeMode.light; // Sepia is essentially a light mode override
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isSepiaKey, enable);
    if (enable) await prefs.setInt(_themeKey, ThemeMode.light.index);
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(12.0, 32.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, _fontSize);
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, family);
  }
  
  Future<void> setReaderMode(ReaderMode mode) async {
    _readerMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_readerModeKey, mode.index);
  }
}
