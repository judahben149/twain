import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/providers/location_providers.dart';
import 'package:twain/screens/user_profile_screen.dart';
import 'package:twain/screens/pairing_screen.dart';
import 'package:twain/services/location_service.dart';
import 'package:twain/services/app_tour_service.dart';
import 'package:twain/widgets/theme_selector.dart';
import 'package:twain/widgets/battery_optimization_dialog.dart';
import 'package:twain/widgets/location_permission_dialog.dart';
import 'package:twain/screens/ios_shortcut_setup_screen.dart';

const String _notificationsEnabledKey = 'notifications_enabled';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? true;
    });
  }

  Future<void> _saveNotificationSetting(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(twainUserProvider).value;
    final isPaired = currentUser?.pairId != null;

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildAppInfo(context),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Account'),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildSettingsTile(
                          icon: Icons.person_outline,
                          title: 'Your Profile',
                          subtitle: currentUser?.displayName ?? 'View and edit your profile',
                          onTap: () {
                            if (currentUser != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileScreen(user: currentUser),
                                ),
                              );
                            }
                          },
                        ),
                        _buildDivider(),
                        _buildSettingsTile(
                          icon: Icons.logout,
                          title: 'Sign Out',
                          subtitle: 'Sign out of your account',
                          onTap: () => _showSignOutDialog(context),
                          isDestructive: true,
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Subscription'),
                      const SizedBox(height: 12),
                      _buildSubscriptionCard(),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Connection'),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        if (isPaired) ...[
                          _buildSettingsTile(
                            icon: Icons.favorite,
                            title: 'Partner Connected',
                            subtitle: 'You are paired with your partner',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: context.twainTheme.activeStatusColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Active',
                                style: TextStyle(
                                  color: context.twainTheme.activeStatusTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          _buildDivider(),
                          _buildSettingsTile(
                            icon: Icons.link_off,
                            title: 'Disconnect',
                            subtitle: 'End connection with your partner',
                            onTap: () => _showDisconnectDialog(context),
                            isDestructive: true,
                          ),
                        ] else ...[
                          _buildSettingsTile(
                            icon: Icons.link,
                            title: 'Get Paired',
                            subtitle: 'Connect with your partner',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PairingScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ]),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Features'),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildDistanceFeatureTile(context),
                        if (isPaired) ...[
                          _buildDivider(),
                          _buildNicknameToggleTile(context),
                        ],
                        if (Platform.isIOS) ...[
                          _buildDivider(),
                          _buildSettingsTile(
                            icon: Icons.app_shortcut,
                            title: 'Wallpaper Shortcuts Setup',
                            subtitle: 'Set up automatic wallpaper syncing on iOS',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const IosShortcutSetupScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ]),
                      const BatteryOptimizationBanner(),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Appearance'),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        const ThemeSelector(),
                      ]),
                      const SizedBox(height: 24),
                      _buildSectionHeader('Help'),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildSettingsTile(
                          icon: Icons.play_circle_outline,
                          title: 'Replay App Tour',
                          subtitle: 'See the app introduction again',
                          onTap: () => _replayAppTour(context),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSectionHeader('About'),
                      const SizedBox(height: 12),
                      _buildSettingsCard([
                        _buildSettingsTile(
                          icon: Icons.info_outline,
                          title: 'App Version',
                          subtitle: '1.0.0',
                        ),
                        _buildDivider(),
                        _buildSettingsTile(
                          icon: Icons.description_outlined,
                          title: 'Terms of Service',
                          subtitle: 'Read our terms',
                          onTap: () => _launchUrl('https://twain-legal-site.vercel.app/terms.html'),
                        ),
                        _buildDivider(),
                        _buildSettingsTile(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          subtitle: 'Read our privacy policy',
                          onTap: () => _launchUrl('https://twain-legal-site.vercel.app/privacy.html'),
                        ),
                      ]),
                      const SizedBox(height: 32),
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
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          ClipOval(
            child: SvgPicture.asset(
              'assets/images/logo_twain_circular.svg',
              width: 80,
              height: 80,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Twain',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The everything app for lovers',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    final twainTheme = context.twainTheme;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: twainTheme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final isTwainPlus = ref.watch(isTwainPlusProvider);
    final isSharedSubscription = ref.watch(isSharedSubscriptionProvider);
    final twainTheme = context.twainTheme;

    String subtitle;
    Widget? trailing;

    if (isTwainPlus) {
      if (isSharedSubscription) {
        subtitle = 'Twain Plus (shared by partner)';
      } else {
        subtitle = 'Twain Plus active';
      }
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: twainTheme.activeStatusColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'PLUS',
          style: TextStyle(
            color: twainTheme.activeStatusTextColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else {
      subtitle = 'Free plan';
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'FREE',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return _buildSettingsCard([
      _buildSettingsTile(
        icon: Icons.workspace_premium,
        title: 'Subscription',
        subtitle: subtitle,
        trailing: trailing,
      ),
    ]);
  }

  Widget _buildDistanceFeatureTile(BuildContext context) {
    final featureState = ref.watch(distanceFeatureProvider);

    return featureState.when(
      data: (enabled) => _buildSettingsTile(
        icon: Icons.social_distance,
        title: 'Distance Meter',
        subtitle: 'Show the distance between you and your partner',
        trailing: Switch(
          value: enabled,
          onChanged: (value) => unawaited(_handleDistanceFeatureToggle(context, value)),
          activeColor: context.twainTheme.iconColor,
        ),
      ),
      loading: () => _buildSettingsTile(
        icon: Icons.social_distance,
        title: 'Distance Meter',
        subtitle: 'Loading preference',
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.twainTheme.iconColor,
          ),
        ),
      ),
      error: (_, __) => _buildSettingsTile(
        icon: Icons.social_distance,
        title: 'Distance Meter',
        subtitle: 'Tap to retry',
        onTap: () => ref.invalidate(distanceFeatureProvider),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          color: context.twainTheme.iconColor,
          onPressed: () => ref.invalidate(distanceFeatureProvider),
        ),
      ),
    );
  }

  Widget _buildNicknameToggleTile(BuildContext context) {
    final currentUser = ref.watch(twainUserProvider).value;
    final partner = ref.watch(pairedUserProvider).value;
    final showNickname = currentUser?.preferences?['show_partner_nickname'] ?? false;
    final hasNickname = partner?.nickname?.isNotEmpty == true;

    return _buildSettingsTile(
      icon: Icons.favorite_outline,
      title: "Show Partner's Nickname",
      subtitle: hasNickname
          ? 'Display "${partner!.nickname}" instead of "${partner.displayName}"'
          : 'Your partner has not set a nickname yet',
      trailing: Switch(
        value: showNickname,
        onChanged: hasNickname
            ? (value) => _handleNicknameToggle(value)
            : null,
        activeColor: context.twainTheme.iconColor,
      ),
    );
  }

  Future<void> _handleNicknameToggle(bool enable) async {
    final currentUser = ref.read(twainUserProvider).value;
    if (currentUser == null) return;

    final updatedPreferences = Map<String, dynamic>.from(currentUser.preferences ?? {});
    updatedPreferences['show_partner_nickname'] = enable;

    try {
      await ref.read(authServiceProvider).updateUserProfile(
        preferences: updatedPreferences,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update setting: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleDistanceFeatureToggle(BuildContext context, bool enable) async {
    final controller = ref.read(distanceFeatureProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    if (!enable) {
      await controller.setEnabled(false);
      return;
    }

    var status = await LocationService.checkPermission();
    if (!status.isGranted) {
      final granted = await LocationPermissionDialog.show(context) ?? false;
      if (!mounted) return;
      if (!granted) {
        _showSnackMessage(
          messenger,
          'Location permission is required to enable the distance meter.',
        );
        await controller.setEnabled(false);
        return;
      }
      status = await LocationService.checkPermission();
      if (!status.isGranted) {
        if (!mounted) return;
        _showSnackMessage(
          messenger,
          'Location permission is required to enable the distance meter.',
        );
        await controller.setEnabled(false);
        return;
      }
    }

    final locationEnabled = await LocationService.isLocationEnabled();
    if (!locationEnabled) {
      if (!mounted) return;
      _showSnackMessage(
        messenger,
        'Turn on location services to use the distance meter.',
      );
      await controller.setEnabled(false);
      return;
    }

    await controller.setEnabled(true);
  }

  void _showSnackMessage(ScaffoldMessengerState messenger, String message) {
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    final color = isDestructive
        ? twainTheme.destructiveColor
        : twainTheme.iconColor;
    final bgColor = isDestructive
        ? twainTheme.destructiveBackgroundColor
        : twainTheme.iconBackgroundColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? twainTheme.destructiveColor
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: Theme.of(context).dividerColor,
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(authServiceProvider).signOut();
              // Invalidate auth provider to trigger AuthGate rebuild
              ref.invalidate(twainUserProvider);
              // Navigate to login and clear navigation stack
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: Text(
              'Sign Out',
              style: TextStyle(color: twainTheme.destructiveColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _replayAppTour(BuildContext context) async {
    final appTourService = AppTourService();
    await appTourService.resetTour();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('App tour will show when you return to the home screen'),
          backgroundColor: context.twainTheme.iconColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not open the link'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _showDisconnectDialog(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Disconnect'),
        content: const Text(
          'Are you sure you want to disconnect from your partner? This will remove all shared data including sticky notes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(authServiceProvider).unpair();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Disconnected from partner'),
                      backgroundColor: theme.colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error disconnecting: $e'),
                      backgroundColor: twainTheme.destructiveColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Disconnect',
              style: TextStyle(color: twainTheme.destructiveColor),
            ),
          ),
        ],
      ),
    );
  }
}
