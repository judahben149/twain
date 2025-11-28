import 'package:flutter/material.dart';
import 'package:twain/models/twain_user.dart';

class TwainAvatar extends StatelessWidget {
  final TwainUser user;
  final double size;
  final Color? color;
  final bool showInitials;
  final bool showBorder;

  const TwainAvatar({
    super.key,
    required this.user,
    this.size = 60,
    this.color,
    this.showInitials = true,
    this.showBorder = true,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? Colors.deepPurple;
    final borderColor = bgColor.withValues(0.3);
    final initials = _getInitials(user.displayName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: borderColor, width: size * 0.08)
            : null,
      ),
      child: ClipOval(
        child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? Image.network(
                user.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitialCircle(bgColor, initials),
              )
            : _buildInitialCircle(bgColor, initials),
      ),
    );
  }

  Widget _buildInitialCircle(Color bgColor, String initials) {
    return Container(
      color: bgColor,
      alignment: Alignment.center,
      child: Text(
        showInitials ? initials : '',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
    );
  }
}
