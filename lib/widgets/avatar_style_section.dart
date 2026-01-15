import 'package:flutter/material.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/constants/avatar_constants.dart';
import 'package:twain/services/avatar_service.dart';
import 'package:twain/widgets/avatar_grid_item.dart';

/// Grouped section for one avatar style
class AvatarStyleSection extends StatelessWidget {
  final AvatarStyle style;
  final List<AvatarOption> avatars;
  final String? selectedAvatarUrl;
  final Function(AvatarOption) onAvatarSelected;

  const AvatarStyleSection({
    super.key,
    required this.style,
    required this.avatars,
    required this.onAvatarSelected,
    this.selectedAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildAvatarGrid(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: twainTheme.iconBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
        border: isDark
            ? Border.all(color: theme.dividerColor, width: 0.5)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            style.icon,
            color: twainTheme.iconColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            style.displayName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: twainTheme.iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: avatars.length,
      itemBuilder: (context, index) {
        final avatar = avatars[index];
        final isSelected = selectedAvatarUrl == avatar.url;

        return AvatarGridItem(
          avatar: avatar,
          isSelected: isSelected,
          onTap: () => onAvatarSelected(avatar),
        );
      },
    );
  }
}
