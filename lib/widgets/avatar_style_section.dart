import 'package:flutter/material.dart';
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
          _buildHeader(),
          const SizedBox(height: 16),
          _buildAvatarGrid(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF3E5F5),
            Color(0xFFFFE6F0),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            style.icon,
            color: const Color(0xFF9C27B0),
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            style.displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF9C27B0),
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
