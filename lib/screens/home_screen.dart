import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/sticky_notes_screen.dart';
import 'package:twain/screens/user_profile_screen.dart';
import 'package:twain/screens/partner_profile_screen.dart';
import 'package:twain/screens/pairing_screen.dart';
import 'package:twain/screens/wallpaper_screen.dart';
import 'package:twain/screens/shared_board_screen.dart';
import 'package:twain/screens/settings_screen.dart';
import 'package:twain/widgets/stable_avatar.dart';
import 'package:twain/widgets/battery_optimization_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasCheckedBatteryOptimization = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkBatteryOptimization();
  }

  Future<void> _checkBatteryOptimization() async {
    if (_hasCheckedBatteryOptimization) return;
    _hasCheckedBatteryOptimization = true;

    // Wait for the screen to be fully built
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Only show if user is paired (uses wallpaper sync feature)
    final currentUser = ref.read(twainUserProvider).value;
    if (currentUser?.pairId == null) return;

    // Show the dialog if needed
    await BatteryOptimizationDialog.show(context);
  }

  void _handleFeatureTap({
    required BuildContext context,
    required bool isPaired,
    required VoidCallback onPaired,
  }) {
    if (isPaired) {
      onPaired();
    } else {
      final twainTheme = context.twainTheme;
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
          backgroundColor: twainTheme.iconColor,
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
        decoration: _buildGradientBackground(context),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildConnectionCard(context, currentUser),
                      const SizedBox(height: 32),
                      _buildFeatureCard(
                        context: context,
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
                        context: context,
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
                        context: context,
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

  BoxDecoration _buildGradientBackground(BuildContext context) {
    final twainTheme = context.twainTheme;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: twainTheme.gradientColors,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            child: Row(
              children: [
                ClipOval(
                  child: SvgPicture.asset(
                    'assets/images/logo_twain_circular.svg',
                    width: 44,
                    height: 44,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Twain',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                iconSize: 28,
                color: theme.colorScheme.onSurface,
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
                    color: twainTheme.iconColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context, dynamic currentUser) {
    final isPaired = currentUser?.pairId != null;
    final pairedUserAsync = ref.watch(pairedUserProvider);
    final twainTheme = context.twainTheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: twainTheme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
        border: context.isDarkMode
            ? Border.all(color: theme.dividerColor, width: 0.5)
            : null,
      ),
      child: isPaired
          ? _buildPairedContent(context, currentUser, pairedUserAsync)
          : _buildUnpairedContent(context, currentUser),
    );
  }

  Widget _buildPairedContent(
      BuildContext context, dynamic currentUser, AsyncValue<dynamic> pairedUserAsync) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return Column(
      children: [
        Text(
          'Connected with',
          style: TextStyle(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            currentUser != null
                ? _buildAvatarWithTwainAvatar(
                    context: context,
                    user: currentUser,
                    name: 'You',
                    color: AppThemes.appAccentColor,
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
                    context: context,
                    label: 'YO',
                    name: 'You',
                    color: AppThemes.appAccentColor,
                    onTap: null,
                  ),
            const SizedBox(width: 16),
            Row(
              children: List.generate(
                3,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            pairedUserAsync.when(
              data: (partner) => partner != null
                  ? _buildAvatarWithTwainAvatar(
                      context: context,
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
                      context: context,
                      label: 'PA',
                      name: 'Partner',
                      color: const Color(0xFFE91E63),
                      onTap: null,
                    ),
              loading: () => SizedBox(
                width: 80,
                height: 80,
                child: Center(
                  child: CircularProgressIndicator(
                    color: twainTheme.iconColor,
                  ),
                ),
              ),
              error: (_, __) => _buildAvatar(
                context: context,
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
              ? _buildPresenceBadge(context, partner)
              : _buildPresencePlaceholder(context),
          loading: () => SizedBox(
            height: 24,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(twainTheme.iconColor),
              ),
            ),
          ),
          error: (_, __) => _buildPresenceError(context),
        ),
      ],
    );
  }

  Widget _buildUnpairedContent(BuildContext context, dynamic currentUser) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return Column(
      children: [
        Icon(
          Icons.favorite_border,
          size: 60,
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        ),
        const SizedBox(height: 16),
        Text(
          'Not Connected',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Connect with your partner to unlock all features',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
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
            backgroundColor: twainTheme.iconColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 20),
              SizedBox(width: 8),
              Text(
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
    required BuildContext context,
    required TwainUser user,
    required String name,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
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
            child: StableTwainAvatar(
              user: user,
              size: 80,
              color: color,
              showBorder: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({
    required BuildContext context,
    required String label,
    required String name,
    required Color color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
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
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresenceBadge(BuildContext context, TwainUser partner) {
    final twainTheme = context.twainTheme;
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
          ? twainTheme.iconColor
          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
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

  Widget _buildPresencePlaceholder(BuildContext context) {
    return Text(
      'Status unavailable',
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }

  Widget _buildPresenceError(BuildContext context) {
    return Text(
      'Status unavailable',
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: twainTheme.cardBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: context.isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: context.isDarkMode
              ? Border.all(color: theme.dividerColor, width: 0.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: twainTheme.iconBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: twainTheme.iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
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
