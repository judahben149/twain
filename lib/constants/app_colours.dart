import 'package:flutter/material.dart';

class AppColors {
  // ===== PRIMARY COLORS =====
  static const Color primary = Color(0xFF9C27B0);
  static const Color primaryLight = Color(0xFFBA68C8);
  static const Color primaryDark = Color(0xFF6A1B9A);

  // ===== SECONDARY COLORS =====
  static const Color secondary = Color(0xFFFF1493);
  static const Color secondaryLight = Color(0xFFFF69B4);
  static const Color secondaryDark = Color(0xFFC2185B);

  // ===== NEUTRAL COLORS =====
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color greyLight = Color(0xFFF5F5F5);
  static const Color greyDark = Color(0xFF616161);

  // ===== SEMANTIC COLORS =====
  static const Color error = Color(0xFFB00020);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);

  // ===== LIGHT THEME COLORS =====
  static const Color backgroundLight = Color(0xFFFFFAF8);
  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF757575);
  static const Color textHintLight = Color(0xFFBDBDBD);
  static const Color dividerLight = Color(0xFFE0E0E0);

  // Legacy aliases for backward compatibility
  static const Color background = backgroundLight;
  static const Color surface = surfaceLight;
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color textSecondary2 = greyDark;
  static const Color textSecondary3 = greyDark;
  static const Color textHint = textHintLight;

  // ===== DARK THEME COLORS =====
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2C2C2C);
  static const Color textPrimaryDark = Color(0xFFE1E1E1);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textHintDark = Color(0xFF757575);
  static const Color dividerDark = Color(0xFF3D3D3D);

  // Dark theme primary (slightly lighter for better visibility)
  static const Color primaryDarkTheme = Color(0xFFCE93D8);
  static const Color secondaryDarkTheme = Color(0xFFFF80AB);

  // ===== AMOLED THEME COLORS =====
  static const Color backgroundAmoled = Color(0xFF000000);
  static const Color surfaceAmoled = Color(0xFF0A0A0A);
  static const Color cardAmoled = Color(0xFF121212);
  static const Color dividerAmoled = Color(0xFF2A2A2A);

  // ===== SEMANTIC COLORS (DARK VARIANTS) =====
  static const Color errorDark = Color(0xFFCF6679);
  static const Color successDark = Color(0xFF81C784);
  static const Color warningDark = Color(0xFFFFD54F);
  static const Color infoDark = Color(0xFF64B5F6);

  // ===== GRADIENT COLORS =====
  static const List<Color> gradientLight = [
    Color(0xFFF5F5F5),
    Color(0xFFF0E6F0),
    Color(0xFFFFE6F0),
  ];

  static const List<Color> gradientDark = [
    Color(0xFF1A1A2E),
    Color(0xFF16213E),
    Color(0xFF1A1625),
  ];

  static const List<Color> gradientAmoled = [
    Color(0xFF000000),
    Color(0xFF0A0510),
    Color(0xFF050208),
  ];
}

// Optional: If you want to use opacity
extension AppColorsExtension on Color {
  Color withCustomOpacity(double opacity) {
    return withOpacity(opacity);
  }
}
