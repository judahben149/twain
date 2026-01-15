import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/models/app_theme_mode.dart';
import 'package:twain/providers/theme_providers.dart';
import 'package:twain/constants/app_themes.dart';

class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final useSystemColors = ref.watch(useSystemColorsProvider);
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Theme mode options
        for (final mode in AppThemeMode.values)
          _buildThemeOption(
            context: context,
            ref: ref,
            mode: mode,
            isSelected: currentTheme == mode,
            theme: theme,
            twainTheme: twainTheme,
          ),

        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Divider(
            height: 1,
            color: theme.dividerColor,
          ),
        ),

        // System colors checkbox
        _buildSystemColorsOption(
          context: context,
          ref: ref,
          isEnabled: useSystemColors,
          theme: theme,
          twainTheme: twainTheme,
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required AppThemeMode mode,
    required bool isSelected,
    required ThemeData theme,
    required TwainThemeExtension twainTheme,
  }) {
    return InkWell(
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(mode);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? twainTheme.iconColor.withOpacity(0.15)
                    : twainTheme.iconBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                mode.icon,
                color: isSelected
                    ? twainTheme.iconColor
                    : theme.colorScheme.onSurface.withOpacity(0.6),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: twainTheme.iconColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemColorsOption({
    required BuildContext context,
    required WidgetRef ref,
    required bool isEnabled,
    required ThemeData theme,
    required TwainThemeExtension twainTheme,
  }) {
    return InkWell(
      onTap: () {
        ref.read(useSystemColorsProvider.notifier).setUseSystemColors(!isEnabled);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isEnabled
                    ? twainTheme.iconColor.withOpacity(0.15)
                    : twainTheme.iconBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.palette_outlined,
                color: isEnabled
                    ? twainTheme.iconColor
                    : theme.colorScheme.onSurface.withOpacity(0.6),
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Colors',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Use colors from your device wallpaper',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: isEnabled,
              onChanged: (value) {
                ref
                    .read(useSystemColorsProvider.notifier)
                    .setUseSystemColors(value ?? false);
              },
              activeColor: twainTheme.iconColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
