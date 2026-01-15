import 'package:flutter/material.dart';

enum AppThemeMode {
  light,
  dark,
  amoled;

  String get displayName {
    switch (this) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.amoled:
        return 'Midnight';
    }
  }

  String get description {
    switch (this) {
      case AppThemeMode.light:
        return 'Classic light theme';
      case AppThemeMode.dark:
        return 'Easy on the eyes';
      case AppThemeMode.amoled:
        return 'Pure black for OLED screens';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.amoled:
        return Icons.brightness_2;
    }
  }
}
