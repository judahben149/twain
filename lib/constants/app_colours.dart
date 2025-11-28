import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF9C27B0);
  static const Color primaryLight = Color(0xFFBA68C8);
  static const Color primaryDark = Color(0xFF6A1B9A);

  // Secondary colors
  static const Color secondary = Color(0xFFFF1493);
  static const Color secondaryLight = Color(0xFFFF69B4);
  static const Color secondaryDark = Color(0xFFC2185B);

  // Neutral colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color greyLight = Color(0xFFF5F5F5);
  static const Color greyDark = Color(0xFF616161);

  // Semantic colors
  static const Color error = Color(0xFFB00020);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);

  // Background
  static const Color background = Color(0xFFFFFAF8);
  static const Color surface = Color(0xFFFAFAFA);

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textSecondary2 = greyDark;
  static const Color textSecondary3 = greyDark;
  static const Color textHint = Color(0xFFBDBDBD);
}

// Optional: If you want to use opacity
extension AppColorsExtension on Color {
  Color withCustomOpacity(double opacity) {
    return withOpacity(opacity);
  }
}