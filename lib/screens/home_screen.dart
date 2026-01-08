import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/services/auth_service.dart';
import 'package:twain/screens/sticky_notes_screen.dart';
import 'package:twain/screens/user_profile_screen.dart';
import 'package:twain/screens/partner_profile_screen.dart';
import 'package:twain/screens/pairing_screen.dart';
import 'package:twain/screens/wallpaper_screen.dart';
import 'package:twain/screens/shared_board_screen.dart';
import 'package:twain/widgets/main_avatar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  void _handleFeatureTap({
    required BuildContext context,
    required bool isPaired,
    required VoidCallback onPaired,
  }) {
    if (isPaired) {
      onPaired();
    } else {
      // Clear any existing snackbars first
      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connect with your partner to unlock this feature',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF9C27B0),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Get Paired',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PairingScreen(),
                ),
              );
            },
          ),
          dismissDirection: DismissDirection.horizontal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(twainUserProvider).value;

    return Scaffold(
      body: Container(
        decoration: _buildGradientBackground(),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildConnectionCard(currentUser),
                      const SizedBox(height: 32),
                      _buildFeatureCard(
                        icon: Icons.wallpaper_outlined,
                        title: 'Wallpaper',
                        subtitle: 'Sync your home screens',
                        colors: [
                          const Color(0xFFE8D5F2),
                          const Color(0xFFFCE4EC),
                        ],
                        onTap: () => _handleFeatureTap(
                          context: context,
                          isPaired: currentUser?.pairId != null,
                          onPaired: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WallpaperScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureCard(
                        icon: Icons.photo_library_outlined,
                        title: 'Shared Board',
                        subtitle: 'Photos & memories',
                        colors: [
                          const Color(0xFFE3F2FD),
                          const Color(0xFFFFF9C4),
                          const Color(0xFFC8E6C9),
                        ],
                        onTap: () => _handleFeatureTap(
                          context: context,
                          isPaired: currentUser?.pairId != null,
                          onPaired: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SharedBoardScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureCard(
                        icon: Icons.sticky_note_2_outlined,
                        title: 'Sticky Notes',
                        subtitle: 'Leave sweet messages',
                        colors: [
                          const Color(0xFFFFF9C4),
                          const Color(0xFFFCE4EC),
                          const Color(0xFFE1BEE7),
                        ],
                        onTap: () => _handleFeatureTap(
                          context: context,
                          isPaired: currentUser?.pairId != null,
                          onPaired: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const StickyNotesScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildGradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFF5F5F5),
          Color(0xFFF0E6F0),
          Color(0xFFFFE6F0),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // App logo
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE91E63),
                  const Color(0xFF9C27B0),
                ],
              ),
            ),
            child: const Center(
              child: Text(
                'T',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Twain',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          const Spacer(),
          // Notification bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                iconSize: 28,
                color: AppColors.black,
                onPressed: () {
                  // TODO: Show notifications
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(dynamic currentUser) {
    final isPaired = currentUser?.pairId != null;
    final pairedUserAsync = ref.watch(pairedUserProvider);

    return Container(
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
      child: isPaired
          ? _buildPairedContent(currentUser, pairedUserAsync)
          : _buildUnpairedContent(currentUser),
    );
  }

  Widget _buildPairedContent(dynamic currentUser, AsyncValue<dynamic> pairedUserAsync) {
    return Column(
      children: [
        const Text(
          'Connected with',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary3,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Current user avatar
            currentUser != null
                ? _buildAvatarWithTwainAvatar(
                    user: currentUser,
                    name: 'You',
                    color: const Color(0xFF9C27B0),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              UserProfileScreen(user: currentUser),
                        ),
                      );
                    },
                  )
                : _buildAvatar(
                    label: 'YO',
                    name: 'You',
                    color: const Color(0xFF9C27B0),
                    onTap: null,
                  ),
            const SizedBox(width: 16),
            // Connection dots
            Row(
              children: List.generate(
                3,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Partner avatar
            pairedUserAsync.when(
              data: (partner) => partner != null
                  ? _buildAvatarWithTwainAvatar(
                      user: partner,
                      name: partner.displayName ?? 'Partner',
                      color: const Color(0xFFE91E63),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PartnerProfileScreen(partner: partner),
                          ),
                        );
                      },
                    )
                  : _buildAvatar(
                      label: 'PA',
                      name: 'Partner',
                      color: const Color(0xFFE91E63),
                      onTap: null,
                    ),
              loading: () => const SizedBox(
                width: 80,
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => _buildAvatar(
                label: 'PA',
                name: 'Partner',
                color: const Color(0xFFE91E63),
                onTap: null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        pairedUserAsync.when(
          data: (partner) => partner != null
              ? _buildPresenceBadge(partner)
              : _buildPresencePlaceholder(),
          loading: () => const SizedBox(
            height: 24,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Color(0xFF9C27B0)),
              ),
            ),
          ),
          error: (_, __) => _buildPresenceError(),
        ),
      ],
    );
  }

  Widget _buildUnpairedContent(dynamic currentUser) {
    return Column(
      children: [
        Icon(
          Icons.favorite_border,
          size: 60,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 16),
        const Text(
          'Not Connected',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect with your partner to unlock all features',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PairingScreen(),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9C27B0),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Get Paired',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarWithTwainAvatar({
    required TwainUser user,
    required String name,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TwainAvatar(
              user: user,
              size: 80,
              color: color,
              showBorder: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required String label,
    required String name,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceBadge(TwainUser partner) {
    final status = (partner.status ?? '').toLowerCase();
    final lastActive = partner.lastActiveAt ?? partner.updatedAt;
    final now = DateTime.now();
    final minutesSinceActive =
        now.isAfter(lastActive) ? now.difference(lastActive).inMinutes : 0;

    Color color;
    String text;

    if (status == 'online') {
      color = const Color(0xFFE91E63);
      text = 'Online now';
    } else {
      color = minutesSinceActive <= 59
          ? const Color(0xFF9C27B0)
          : Colors.grey.shade600;
      text = 'Last active: ${_formatRelativeTime(lastActive)}';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPresencePlaceholder() {
    return Text(
      'Status unavailable',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _buildPresenceError() {
    return Text(
      'Status unavailable',
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade600,
      ),
    );
  }

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    if (timestamp.isAfter(now)) return 'just now';

    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return '$minutes min${minutes == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      final hours = diff.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    } else {
      final days = diff.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    }
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF9C27B0),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Color preview
            Row(
              children: colors.map((color) {
                return Container(
                  margin: const EdgeInsets.only(left: 6),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
