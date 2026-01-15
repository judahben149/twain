import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/app_theme_mode.dart';
import 'package:twain/providers/theme_providers.dart';

class DynamicThemeBuilder extends ConsumerWidget {
  final Widget Function(ThemeData light, ThemeData dark, ThemeMode mode)
      builder;

  const DynamicThemeBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appThemeMode = ref.watch(themeModeProvider);
    final useSystemColors = ref.watch(useSystemColorsProvider);
    final themeMode = ref.watch(materialThemeModeProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ThemeData lightTheme;
        ThemeData darkTheme;

        final hasDynamicColors = lightDynamic != null && darkDynamic != null;

        if (useSystemColors && hasDynamicColors) {
          // Apply system colors based on theme mode
          lightTheme = _buildSystemColorTheme(
            lightDynamic!,
            Brightness.light,
            appThemeMode,
          );
          darkTheme = _buildSystemColorTheme(
            darkDynamic!,
            Brightness.dark,
            appThemeMode,
          );
        } else {
          // Use default app themes
          lightTheme = ref.watch(lightThemeProvider);
          darkTheme = ref.watch(darkThemeProvider);
        }

        return builder(lightTheme, darkTheme, themeMode);
      },
    );
  }

  ThemeData _buildSystemColorTheme(
    ColorScheme dynamicScheme,
    Brightness brightness,
    AppThemeMode appThemeMode,
  ) {
    final isLight = brightness == Brightness.light;
    final isAmoled = appThemeMode == AppThemeMode.amoled;

    // Get base theme
    ThemeData baseTheme;
    if (isLight) {
      baseTheme = AppThemes.lightTheme;
    } else if (isAmoled) {
      baseTheme = AppThemes.amoledTheme;
    } else {
      baseTheme = AppThemes.darkTheme;
    }

    // For AMOLED, keep pure black background but use system colors for accents
    Color scaffoldBg;
    Color cardBg;
    List<Color> gradientColors;

    if (isAmoled) {
      // AMOLED: Keep pure black background
      scaffoldBg = AppColors.backgroundAmoled;
      cardBg = AppColors.cardAmoled;
      gradientColors = AppColors.gradientAmoled;
    } else if (isLight) {
      // Light: Use system colors for background with light tints
      final primaryTint = dynamicScheme.primary.withOpacity(0.08);
      scaffoldBg = Color.alphaBlend(primaryTint, dynamicScheme.surface);
      cardBg = dynamicScheme.surfaceContainerHigh;
      gradientColors = [
        Color.alphaBlend(
          dynamicScheme.primary.withOpacity(0.05),
          dynamicScheme.surfaceContainerLowest,
        ),
        Color.alphaBlend(
          dynamicScheme.primary.withOpacity(0.04),
          dynamicScheme.surfaceContainerLow,
        ),
        Color.alphaBlend(
          dynamicScheme.primary.withOpacity(0.03),
          dynamicScheme.surfaceContainer,
        ),
      ];
    } else {
      // Dark: Slightly tint background with system colors
      final systemTint = dynamicScheme.primary.withOpacity(0.05);
      scaffoldBg = Color.alphaBlend(systemTint, AppColors.backgroundDark);
      cardBg = Color.alphaBlend(systemTint, AppColors.cardDark);
      gradientColors = [
        Color.alphaBlend(dynamicScheme.primary.withOpacity(0.08), const Color(0xFF1A1A2E)),
        Color.alphaBlend(dynamicScheme.primary.withOpacity(0.05), const Color(0xFF16213E)),
        Color.alphaBlend(dynamicScheme.primary.withOpacity(0.03), const Color(0xFF1A1625)),
      ];
    }

    // Icon and accent colors from system
    final iconColor = dynamicScheme.primary;
    final iconBgColor = isLight
        ? dynamicScheme.primaryContainer
        : dynamicScheme.primary.withOpacity(0.15);

    return baseTheme.copyWith(
      colorScheme: dynamicScheme,
      primaryColor: dynamicScheme.primary,
      scaffoldBackgroundColor: scaffoldBg,
      cardColor: cardBg,
      textTheme: GoogleFonts.jostTextTheme(
        isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return dynamicScheme.primary;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            final opacity = isLight ? 0.4 : 0.5;
            return dynamicScheme.primary.withOpacity(opacity);
          }
          return null;
        }),
      ),
      extensions: [
        TwainThemeExtension(
          gradientColors: gradientColors,
          cardBackgroundColor: isAmoled ? cardBg : cardBg.withOpacity(0.9),
          iconColor: iconColor,
          iconBackgroundColor: iconBgColor,
          destructiveColor: isLight
              ? const Color(0xFFE53935)
              : const Color(0xFFEF5350),
          destructiveBackgroundColor: isLight
              ? const Color(0xFFFFEBEE)
              : (isAmoled ? const Color(0xFF2D1010) : const Color(0xFF3D1B1B)),
          activeStatusColor: isLight
              ? const Color(0xFFE8F5E9)
              : (isAmoled ? const Color(0xFF0F2D0F) : const Color(0xFF1B3D1B)),
          activeStatusTextColor: isLight
              ? const Color(0xFF4CAF50)
              : const Color(0xFF81C784),
        ),
      ],
    );
  }
}
