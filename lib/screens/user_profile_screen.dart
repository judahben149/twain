import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/twain_user.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/avatar_selector_screen.dart';
import 'package:twain/screens/edit_profile_screen.dart';
import 'package:twain/widgets/stable_avatar.dart';

class UserProfileScreen extends ConsumerWidget {
  final TwainUser user;

  const UserProfileScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    // Watch for real-time updates to the current user
    final currentUserAsync = ref.watch(twainUserProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: twainTheme.gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, theme),
              Expanded(
                child: currentUserAsync.when(
                  data: (currentUser) {
                    if (currentUser == null) {
                      return Center(
                        child: Text(
                          'No user logged in',
                          style: TextStyle(color: theme.colorScheme.onSurface),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          _buildAvatar(context, currentUser, twainTheme),
                          const SizedBox(height: 24),
                          _buildInfoCard(currentUser, theme, twainTheme),
                        ],
                      ),
                    );
                  },
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: twainTheme.iconColor,
                    ),
                  ),
                  error: (error, stack) => Center(
                    child: Text(
                      'Error: $error',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final twainTheme = context.twainTheme;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          Text(
            'Your Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: twainTheme.iconColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
            },
            tooltip: 'Edit Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, TwainUser user, TwainThemeExtension twainTheme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AvatarSelectorScreen(),
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: twainTheme.iconColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: StableTwainAvatar(
              user: user,
              size: 120,
              showBorder: true,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: twainTheme.iconColor,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.edit,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(TwainUser user, ThemeData theme, TwainThemeExtension twainTheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: twainTheme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: theme.brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        border: theme.brightness == Brightness.dark
            ? Border.all(color: theme.dividerColor, width: 0.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Display Name',
            value: user.displayName,
            theme: theme,
            twainTheme: twainTheme,
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            icon: Icons.favorite_outline,
            label: 'Nickname',
            value: user.nickname?.isNotEmpty == true ? user.nickname! : 'Not set',
            theme: theme,
            twainTheme: twainTheme,
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email,
            theme: theme,
            twainTheme: twainTheme,
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Member Since',
            value: _formatDate(user.createdAt),
            theme: theme,
            twainTheme: twainTheme,
          ),
          if (user.metaData?['timezone_utc_offset'] != null) ...[
            const SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Time Zone',
              value: '${user.metaData!['timezone_name'] ?? ''} (${user.metaData!['timezone_utc_offset']})',
              theme: theme,
              twainTheme: twainTheme,
            ),
          ],
          if (user.status != null) ...[
            const SizedBox(height: 20),
            _buildInfoRow(
              icon: Icons.info_outline,
              label: 'Status',
              value: user.status!,
              theme: theme,
              twainTheme: twainTheme,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    required TwainThemeExtension twainTheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: twainTheme.iconBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: twainTheme.iconColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
