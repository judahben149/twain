import 'package:flutter/material.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/widgets/main_avatar.dart';

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
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Current Avatar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9C27B0),
            ),
          ),
          const SizedBox(height: 16),
          TwainAvatar(
            user: user,
            size: 120,
            showBorder: true,
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName ?? 'User',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: isResetting ? null : onReset,
            icon: isResetting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF9C27B0),
                    ),
                  )
                : const Icon(Icons.refresh),
            label: Text(isResetting ? 'Resetting...' : 'Reset to Initials'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF9C27B0),
              side: const BorderSide(color: Color(0xFF9C27B0)),
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
