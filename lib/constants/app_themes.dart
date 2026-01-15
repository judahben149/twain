import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twain/constants/app_colours.dart';

class AppThemes {
  static const seedColor = Colors.pink;

  // Original app accent color (pink/purple)
  static const Color appAccentColor = Color(0xFF9C27B0);
  static const Color appAccentColorLight = Color(0xFFF3E5F5);

  // ===== LIGHT THEME =====
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme.copyWith(
        primary: appAccentColor,
      ),
      textTheme: GoogleFonts.jostTextTheme(ThemeData.light().textTheme),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      cardColor: AppColors.cardLight,
      dividerColor: AppColors.dividerLight,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        color: AppColors.cardLight,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: appAccentColor,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return appAccentColor;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return appAccentColor.withOpacity(0.5);
          }
          return null;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: appAccentColor,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.cardLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      extensions: [
        TwainThemeExtension(
          gradientColors: AppColors.gradientLight,
          cardBackgroundColor: AppColors.cardLight.withOpacity(0.9),
          iconColor: appAccentColor,
          iconBackgroundColor: appAccentColorLight,
          destructiveColor: const Color(0xFFE53935),
          destructiveBackgroundColor: const Color(0xFFFFEBEE),
          activeStatusColor: const Color(0xFFE8F5E9),
          activeStatusTextColor: const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  // ===== DARK THEME =====
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme.copyWith(
        primary: appAccentColor,
      ),
      textTheme: GoogleFonts.jostTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      cardColor: AppColors.cardDark,
      dividerColor: AppColors.dividerDark,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        color: AppColors.cardDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: appAccentColor,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return appAccentColor;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return appAccentColor.withOpacity(0.5);
          }
          return null;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardDark,
        contentTextStyle: TextStyle(color: AppColors.textPrimaryDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      extensions: [
        TwainThemeExtension(
          gradientColors: AppColors.gradientDark,
          cardBackgroundColor: AppColors.cardDark.withOpacity(0.9),
          iconColor: appAccentColor,
          iconBackgroundColor: const Color(0xFF2D1B3D),
          destructiveColor: const Color(0xFFEF5350),
          destructiveBackgroundColor: const Color(0xFF3D1B1B),
          activeStatusColor: const Color(0xFF1B3D1B),
          activeStatusTextColor: const Color(0xFF81C784),
        ),
      ],
    );
  }

  // ===== AMOLED THEME =====
  static ThemeData get amoledTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme.copyWith(
        primary: appAccentColor,
      ),
      textTheme: GoogleFonts.jostTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: AppColors.backgroundAmoled,
      cardColor: AppColors.cardAmoled,
      dividerColor: AppColors.dividerAmoled,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundAmoled,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        color: AppColors.cardAmoled,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.dividerAmoled, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: appAccentColor,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return appAccentColor;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return appAccentColor.withOpacity(0.5);
          }
          return null;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cardAmoled,
        contentTextStyle: TextStyle(color: AppColors.textPrimaryDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.dividerAmoled),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.cardAmoled,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.dividerAmoled),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAmoled,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.dividerAmoled),
        ),
      ),
      extensions: [
        TwainThemeExtension(
          gradientColors: AppColors.gradientAmoled,
          cardBackgroundColor: AppColors.cardAmoled.withOpacity(0.95),
          iconColor: appAccentColor,
          iconBackgroundColor: const Color(0xFF1A0F1F),
          destructiveColor: const Color(0xFFEF5350),
          destructiveBackgroundColor: const Color(0xFF2D1010),
          activeStatusColor: const Color(0xFF0F2D0F),
          activeStatusTextColor: const Color(0xFF81C784),
        ),
      ],
    );
  }
}

/// Custom theme extension for app-specific styling
class TwainThemeExtension extends ThemeExtension<TwainThemeExtension> {
  final List<Color> gradientColors;
  final Color cardBackgroundColor;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color destructiveColor;
  final Color destructiveBackgroundColor;
  final Color activeStatusColor;
  final Color activeStatusTextColor;

  TwainThemeExtension({
    required this.gradientColors,
    required this.cardBackgroundColor,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.destructiveColor,
    required this.destructiveBackgroundColor,
    required this.activeStatusColor,
    required this.activeStatusTextColor,
  });

  @override
  TwainThemeExtension copyWith({
    List<Color>? gradientColors,
    Color? cardBackgroundColor,
    Color? iconColor,
    Color? iconBackgroundColor,
    Color? destructiveColor,
    Color? destructiveBackgroundColor,
    Color? activeStatusColor,
    Color? activeStatusTextColor,
  }) {
    return TwainThemeExtension(
      gradientColors: gradientColors ?? this.gradientColors,
      cardBackgroundColor: cardBackgroundColor ?? this.cardBackgroundColor,
      iconColor: iconColor ?? this.iconColor,
      iconBackgroundColor: iconBackgroundColor ?? this.iconBackgroundColor,
      destructiveColor: destructiveColor ?? this.destructiveColor,
      destructiveBackgroundColor:
          destructiveBackgroundColor ?? this.destructiveBackgroundColor,
      activeStatusColor: activeStatusColor ?? this.activeStatusColor,
      activeStatusTextColor:
          activeStatusTextColor ?? this.activeStatusTextColor,
    );
  }

  @override
  TwainThemeExtension lerp(
      ThemeExtension<TwainThemeExtension>? other, double t) {
    if (other is! TwainThemeExtension) return this;
    return TwainThemeExtension(
      gradientColors: [
        for (int i = 0; i < gradientColors.length; i++)
          Color.lerp(gradientColors[i], other.gradientColors[i], t)!,
      ],
      cardBackgroundColor:
          Color.lerp(cardBackgroundColor, other.cardBackgroundColor, t)!,
      iconColor: Color.lerp(iconColor, other.iconColor, t)!,
      iconBackgroundColor:
          Color.lerp(iconBackgroundColor, other.iconBackgroundColor, t)!,
      destructiveColor:
          Color.lerp(destructiveColor, other.destructiveColor, t)!,
      destructiveBackgroundColor: Color.lerp(
          destructiveBackgroundColor, other.destructiveBackgroundColor, t)!,
      activeStatusColor:
          Color.lerp(activeStatusColor, other.activeStatusColor, t)!,
      activeStatusTextColor:
          Color.lerp(activeStatusTextColor, other.activeStatusTextColor, t)!,
    );
  }
}

/// Extension method for easy access to TwainThemeExtension
extension TwainThemeContext on BuildContext {
  TwainThemeExtension get twainTheme =>
      Theme.of(this).extension<TwainThemeExtension>()!;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
