import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:twain/services/avatar_service.dart';

/// Individual avatar tile in the grid
class AvatarGridItem extends StatelessWidget {
  final AvatarOption avatar;
  final bool isSelected;
  final VoidCallback onTap;
  final double size;

  const AvatarGridItem({
    super.key,
    required this.avatar,
    required this.onTap,
    this.isSelected = false,
    this.size = 70,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: const Color(0xFF9C27B0),
                  width: 3,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF9C27B0).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipOval(
          child: SvgPicture.network(
            avatar.url,
            fit: BoxFit.cover,
            placeholderBuilder: (context) => Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF9C27B0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
