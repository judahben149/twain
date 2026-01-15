import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/models/app_theme_mode.dart';
import 'package:twain/services/theme_service.dart';
import 'package:twain/constants/app_themes.dart';

/// Theme service provider (singleton)
final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService();
});

/// StateNotifier for theme mode management
class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  final ThemeService _themeService;

  ThemeModeNotifier(this._themeService) : super(AppThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    state = await _themeService.loadThemeMode();
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    await _themeService.saveThemeMode(mode);
  }
}

/// StateNotifier for system colors toggle
class UseSystemColorsNotifier extends StateNotifier<bool> {
  final ThemeService _themeService;

  UseSystemColorsNotifier(this._themeService) : super(false) {
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    state = await _themeService.loadUseSystemColors();
  }

  Future<void> setUseSystemColors(bool value) async {
    state = value;
    await _themeService.saveUseSystemColors(value);
  }
}

/// Theme mode provider
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
  final themeService = ref.watch(themeServiceProvider);
  return ThemeModeNotifier(themeService);
});

/// Use system colors provider
final useSystemColorsProvider =
    StateNotifierProvider<UseSystemColorsNotifier, bool>((ref) {
  final themeService = ref.watch(themeServiceProvider);
  return UseSystemColorsNotifier(themeService);
});

/// Computed ThemeMode for MaterialApp
final materialThemeModeProvider = Provider<ThemeMode>((ref) {
  final appThemeMode = ref.watch(themeModeProvider);
  switch (appThemeMode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
    case AppThemeMode.amoled:
      return ThemeMode.dark;
  }
});

/// Light theme provider
final lightThemeProvider = Provider<ThemeData>((ref) {
  return AppThemes.lightTheme;
});

/// Dark theme provider (switches between dark and AMOLED)
final darkThemeProvider = Provider<ThemeData>((ref) {
  final appThemeMode = ref.watch(themeModeProvider);
  return appThemeMode == AppThemeMode.amoled
      ? AppThemes.amoledTheme
      : AppThemes.darkTheme;
});
