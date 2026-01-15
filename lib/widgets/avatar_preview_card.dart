import 'package:flutter/material.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/widgets/stable_avatar.dart';

/// Preview card showing current avatar at top of selector screen
class AvatarPreviewCard extends StatelessWidget {
  final TwainUser user;
  final VoidCallback onReset;
  final bool isResetting;

  const AvatarPreviewCard({
    super.key,
    required this.user,
    required this.onReset,
    this.isResetting = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: twainTheme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
        border: isDark
            ? Border.all(color: theme.dividerColor, width: 0.5)
            : null,
      ),
      child: Column(
        children: [
          Text(
            'Current Avatar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: twainTheme.iconColor,
            ),
          ),
          const SizedBox(height: 16),
          StableTwainAvatar(
            user: user,
            size: 120,
            showBorder: true,
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName ?? 'User',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: isResetting ? null : onReset,
            icon: isResetting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: twainTheme.iconColor,
                    ),
                  )
                : Icon(Icons.refresh, color: twainTheme.iconColor),
            label: Text(isResetting ? 'Resetting...' : 'Reset to Initials'),
            style: OutlinedButton.styleFrom(
              foregroundColor: twainTheme.iconColor,
              side: BorderSide(color: twainTheme.iconColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
