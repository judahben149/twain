import 'package:shared_preferences/shared_preferences.dart';
import 'package:twain/models/app_theme_mode.dart';

class ThemeService {
  static const String _themeKey = 'app_theme_mode';
  static const String _useSystemColorsKey = 'use_system_colors';

  Future<AppThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
    if (themeIndex == null ||
        themeIndex < 0 ||
        themeIndex >= AppThemeMode.values.length) {
      return AppThemeMode.light;
    }
    return AppThemeMode.values[themeIndex];
  }

  Future<void> saveThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  Future<bool> loadUseSystemColors() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useSystemColorsKey) ?? false;
  }

  Future<void> saveUseSystemColors(bool useSystemColors) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useSystemColorsKey, useSystemColors);
  }
}
