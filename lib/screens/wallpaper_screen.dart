import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/wallpaper.dart';
import 'package:twain/models/app_theme_mode.dart';
import 'package:twain/providers/wallpaper_providers.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/providers/theme_providers.dart';
import 'package:twain/screens/shared_board_screen.dart';
import 'package:twain/screens/wallpaper_preview_screen.dart';
import 'package:twain/screens/unsplash_browser_screen.dart';
import 'package:twain/screens/folders_list_screen.dart';
import 'package:twain/screens/paywall_screen.dart';
import 'package:twain/services/wallpaper_manager_service.dart';
import 'package:twain/services/cache/twain_cache_managers.dart';
import 'package:twain/utils/image_url_utils.dart';
import 'package:twain/screens/wallpaper_detail_screen.dart';

enum _WallpaperSource { sharedBoard, device, unsplash }

class WallpaperScreen extends ConsumerStatefulWidget {
  const WallpaperScreen({super.key});

  @override
  ConsumerState<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends ConsumerState<WallpaperScreen> {
  final Set<String> _applyingWallpapers = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    final isLight = !context.isDarkMode;
    final appThemeMode = ref.watch(themeModeProvider);
    final isMidnight = appThemeMode == AppThemeMode.amoled;
    final scaffoldColor = isLight
        ? Color.alphaBlend(
            twainTheme.iconColor.withOpacity(0.06),
            theme.colorScheme.surface,
          )
        : (isMidnight ? AppColors.backgroundAmoled : theme.colorScheme.surface);
    final wallpapersAsync = ref.watch(wallpapersStreamProvider);
    final currentUser = ref.watch(twainUserProvider).value;
    final partner = ref.watch(pairedUserProvider).value;
    final rawPartnerName = partner?.displayName;
    final partnerDisplayName = rawPartnerName?.trim();
    final useDefaultPartnerName = partnerDisplayName?.isEmpty ?? true;
    final partnerLabel = useDefaultPartnerName
        ? 'your partner'
        : partnerDisplayName ?? 'your partner';

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        title: Text(
          'Wallpaper Sync',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: () => _showMomentsSheet(
                wallpapersAsync: wallpapersAsync,
                theme: theme,
                twainTheme: twainTheme,
                currentUserId: currentUser?.id,
              ),
              style: TextButton.styleFrom(
                backgroundColor: context.isDarkMode
                    ? theme.colorScheme.surface.withOpacity(0.35)
                    : theme.colorScheme.surface,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timeline,
                    size: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Moments',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: wallpapersAsync.when(
        data: (wallpapers) => _buildContent(
          context: context,
          theme: theme,
          twainTheme: twainTheme,
          wallpapers: wallpapers,
          currentUserId: currentUser?.id,
          partnerLabel: partnerLabel,
          wallpapersAsync: wallpapersAsync,
        ),
        loading: () => Center(
          child: CircularProgressIndicator(
            color: twainTheme.iconColor,
          ),
        ),
        error: (error, stack) => _buildErrorState(theme, twainTheme, error),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required ThemeData theme,
    required TwainThemeExtension twainTheme,
    required List<Wallpaper> wallpapers,
    required String? currentUserId,
    required String partnerLabel,
    required AsyncValue<List<Wallpaper>> wallpapersAsync,
  }) {
    final latestWallpaper = wallpapers.isNotEmpty ? wallpapers.first : null;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCurrentWallpaperSection(
              context: context,
              theme: theme,
              twainTheme: twainTheme,
              wallpaper: latestWallpaper,
              currentUserId: currentUserId,
              partnerLabel: partnerLabel,
            ),
            const SizedBox(height: 24),
            _buildActionSection(
              context: context,
              theme: theme,
              twainTheme: twainTheme,
              partnerLabel: partnerLabel,
            ),
            const SizedBox(height: 32),
            _buildMomentsPreview(
              context: context,
              theme: theme,
              twainTheme: twainTheme,
              wallpapers: wallpapers,
              currentUserId: currentUserId,
              wallpapersAsync: wallpapersAsync,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    ThemeData theme,
    TwainThemeExtension twainTheme,
    Object error,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: twainTheme.destructiveColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading wallpapers',
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              '$error',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWallpaperSection({
    required BuildContext context,
    required ThemeData theme,
    required TwainThemeExtension twainTheme,
    required Wallpaper? wallpaper,
    required String? currentUserId,
    required String partnerLabel,
  }) {
    final lastUpdatedBy = wallpaper == null
        ? null
        : (wallpaper.senderId == currentUserId ? 'You' : partnerLabel);
    final updatedAt = wallpaper == null
        ? null
        : _formatDateTime(
            wallpaper.appliedAt ?? wallpaper.createdAt,
          );
    final applyToText =
        wallpaper == null ? null : _getApplyToText(wallpaper.applyTo);
    final showFallbackLabel = wallpaper == null ? false : !Platform.isAndroid;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: twainTheme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
        border: context.isDarkMode
            ? Border.all(color: theme.dividerColor, width: 0.6)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Current wallpaper',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          _buildDevicePreviewFrame(context, theme, twainTheme, wallpaper),
          const SizedBox(height: 16),
          if (wallpaper == null) ...[
            Text(
              'No wallpaper set yet.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Tap “Change wallpaper” to choose something together.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              'Last updated by $lastUpdatedBy · $updatedAt',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            if (applyToText?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                'Applied ${applyToText!}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (showFallbackLabel) ...[
              const SizedBox(height: 8),
              Text(
                'Showing last set wallpaper',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.45),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDevicePreviewFrame(
    BuildContext context,
    ThemeData theme,
    TwainThemeExtension twainTheme,
    Wallpaper? wallpaper,
  ) {
    final imageUrl = wallpaper?.imageUrl;
    final optimizedUrl = imageUrl != null
        ? buildOptimizedImageUrl(
            imageUrl,
            width: 1440,
            quality: 75,
          )
        : null;

    Widget imageChild;
    if (optimizedUrl != null) {
      imageChild = CachedNetworkImage(
        imageUrl: optimizedUrl,
        cacheManager:
            TwainCacheManagers.getManager(TwainCacheBucket.wallpaperImages),
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 120),
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholderFadeInDuration: const Duration(milliseconds: 120),
        useOldImageOnUrlChange: true,
        progressIndicatorBuilder: (context, url, progress) {
          final value = progress.progress;
          return Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 2,
                color: twainTheme.iconColor,
              ),
            ),
          );
        },
        errorWidget: (context, url, error) => Container(
          color: theme.colorScheme.surface,
          child: Icon(
            Icons.wallpaper,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
            size: 48,
          ),
        ),
      );
    } else {
      imageChild = Container(
        color: Colors.black,
        child: Icon(
          Icons.wallpaper,
          color: theme.colorScheme.onSurface.withOpacity(0.2),
          size: 48,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * 0.6;
        final frameWidth = maxWidth.clamp(0, 240).toDouble();
        final frameHeight = frameWidth / 9 * 19.5;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: frameWidth,
              maxHeight: frameHeight + 32,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
                boxShadow: context.isDarkMode
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
              ),
              child: AspectRatio(
                aspectRatio: 9 / 19.5,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: imageChild,
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 70,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionSection({
    required BuildContext context,
    required ThemeData theme,
    required TwainThemeExtension twainTheme,
    required String partnerLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: twainTheme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
        border: context.isDarkMode
            ? Border.all(color: theme.dividerColor, width: 0.6)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ready for a refresh?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _startChangeWallpaperFlow(partnerLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: twainTheme.iconColor,
              foregroundColor: theme.colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: context.isDarkMode ? 0 : 2,
            ),
            child: const Text(
              'Change wallpaper',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              // Check for Twain Plus subscription
              var isTwainPlus = ref.read(isTwainPlusProvider);
              if (!isTwainPlus) {
                final purchased = await PaywallScreen.show(
                  context,
                  feature: PaywallFeature.wallpaperRotation,
                );
                if (!purchased) return;
                if (!mounted) return;
                // Invalidate provider to reflect updated status in UI
                ref.invalidate(subscriptionStatusProvider);
              }
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FoldersListScreen(),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: twainTheme.iconColor,
              side: BorderSide(
                color: twainTheme.iconColor,
                width: 2,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.autorenew_rounded,
                  size: 20,
                  color: twainTheme.iconColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Wallpaper rotation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!ref.watch(isTwainPlusProvider)) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: twainTheme.iconColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PLUS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Quick actions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickActionTile(
            context: context,
            theme: theme,
            twainTheme: twainTheme,
            icon: Icons.photo_library,
            title: 'Choose from Shared Board',
            subtitle: 'Use photos you both already love.',
            onTap: _openSharedBoard,
          ),
          const SizedBox(height: 12),
          _buildQuickActionTile(
            context: context,
            theme: theme,
            twainTheme: twainTheme,
            icon: Icons.phone_android,
            title: 'Choose from Device',
            subtitle: 'Pick something personal from your gallery.',
            onTap: () => _pickFromDevice(context),
          ),
          const SizedBox(height: 12),
          _buildQuickActionTile(
            context: context,
            theme: theme,
            twainTheme: twainTheme,
            icon: Icons.explore_outlined,
            title: 'Browse Wallpapers',
            subtitle: 'Discover fresh Unsplash picks together.',
            onTap: _openUnsplashBrowser,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile({
    required BuildContext context,
    required ThemeData theme,
    required TwainThemeExtension twainTheme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final iconContainerColor = twainTheme.iconColor.withOpacity(0.12);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withOpacity(
              context.isDarkMode ? 0.4 : 0.2,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconContainerColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: twainTheme.iconColor,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMomentsPreview({
    required BuildContext context,
    required ThemeData theme,
    required TwainThemeExtension twainTheme,
    required List<Wallpaper> wallpapers,
    required String? currentUserId,
    required AsyncValue<List<Wallpaper>> wallpapersAsync,
  }) {
    final recentWallpapers = wallpapers.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: twainTheme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
        border: context.isDarkMode
            ? Border.all(color: theme.dividerColor, width: 0.6)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Wallpaper moments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showMomentsSheet(
                  wallpapersAsync: wallpapersAsync,
                  theme: theme,
                  twainTheme: twainTheme,
                  currentUserId: currentUserId,
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentWallpapers.isEmpty)
            _buildEmptyMomentsPreview(theme)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentWallpapers.length,
              itemBuilder: (context, index) {
                final wallpaper = recentWallpapers[index];
                final isCurrentUser = wallpaper.senderId == currentUserId;
                return _buildWallpaperHistoryCard(
                  context,
                  wallpaper,
                  isCurrentUser,
                  currentUserId ?? '',
                  theme,
                  twainTheme,
                  compact: true,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyMomentsPreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.wallpaper_outlined,
            size: 40,
            color: theme.colorScheme.onSurface.withOpacity(0.25),
          ),
          const SizedBox(height: 12),
          Text(
            'No moments yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set a wallpaper to start tracking moments here.',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _showMomentsSheet({
    required AsyncValue<List<Wallpaper>> wallpapersAsync,
    required ThemeData theme,
    required TwainThemeExtension twainTheme,
    required String? currentUserId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final modalTheme = Theme.of(context);
        final modalTwainTheme = context.twainTheme;

        return DraggableScrollableSheet(
          expand: false,
          minChildSize: 0.3,
          initialChildSize: 0.45,
          maxChildSize: 1.0,
          snap: true,
          snapSizes: const [0.3, 0.6, 1.0],
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                color: modalTwainTheme.cardBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: context.isDarkMode
                    ? Border.all(color: modalTheme.dividerColor, width: 0.6)
                    : null,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: modalTheme.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Wallpaper moments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: modalTheme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: wallpapersAsync.when(
                      data: (wallpapers) {
                        if (wallpapers.isEmpty) {
                          return _buildEmptyMomentsState(modalTheme);
                        }
                        return ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                          itemCount: wallpapers.length,
                          itemBuilder: (context, index) {
                            final wallpaper = wallpapers[index];
                            final isCurrentUser =
                                wallpaper.senderId == currentUserId;
                            return _buildWallpaperHistoryCard(
                              context,
                              wallpaper,
                              isCurrentUser,
                              currentUserId ?? '',
                              modalTheme,
                              modalTwainTheme,
                              compact: true,
                            );
                          },
                        );
                      },
                      loading: () => Center(
                        child: CircularProgressIndicator(
                          color: modalTwainTheme.iconColor,
                        ),
                      ),
                      error: (error, stack) =>
                          _buildErrorState(modalTheme, modalTwainTheme, error),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyMomentsState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wallpaper_outlined,
              size: 56,
              color: theme.colorScheme.onSurface.withOpacity(0.25),
            ),
            const SizedBox(height: 16),
            Text(
              'No moments yet. Set a wallpaper to start.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startChangeWallpaperFlow(String partnerLabel) async {
    final selection = await _showWhoSelectionSheet(partnerLabel);
    if (selection == null) return;

    ref.read(wallpaperApplyToSelectionProvider.notifier).state = selection;

    if (!mounted) return;

    final source = await _showSourcePicker();
    if (!mounted || source == null) return;

    switch (source) {
      case _WallpaperSource.sharedBoard:
        _openSharedBoard();
        break;
      case _WallpaperSource.device:
        _pickFromDevice(context);
        break;
      case _WallpaperSource.unsplash:
        _openUnsplashBrowser();
        break;
    }
  }

  Future<String?> _showWhoSelectionSheet(String partnerLabel) async {
    final initialSelection = ref.read(wallpaperApplyToSelectionProvider);
    final resolvedPartnerLabel = partnerLabel.isEmpty ? 'your partner' : partnerLabel;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final modalTheme = Theme.of(context);
        final modalTwainTheme = context.twainTheme;
        String selection = initialSelection;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: modalTwainTheme.cardBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: context.isDarkMode
                    ? Border.all(color: modalTheme.dividerColor, width: 0.6)
                    : null,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: modalTheme.dividerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Who is this for?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: modalTheme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildWhoOptionCard(
                        theme: modalTheme,
                        twainTheme: modalTwainTheme,
                        title: 'Both of us (recommended)',
                        subtitle: 'Syncs instantly for you and $resolvedPartnerLabel.',
                        selected: selection == 'both',
                        onTap: () => setModalState(() => selection = 'both'),
                      ),
                      const SizedBox(height: 12),
                      _buildWhoOptionCard(
                        theme: modalTheme,
                        twainTheme: modalTwainTheme,
                        title: 'Just my partner',
                        subtitle:
                            "Only $resolvedPartnerLabel's wallpaper will be changed.",
                        selected: selection == 'partner',
                        onTap: () => setModalState(() => selection = 'partner'),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, selection),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: modalTwainTheme.iconColor,
                          foregroundColor: modalTheme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWhoOptionCard({
    required ThemeData theme,
    required TwainThemeExtension twainTheme,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? twainTheme.iconColor.withOpacity(0.12)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? twainTheme.iconColor
                : theme.dividerColor.withOpacity(0.7),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color:
                  selected ? twainTheme.iconColor : theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
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
          ],
        ),
      ),
    );
  }

  Future<_WallpaperSource?> _showSourcePicker() {
    return showModalBottomSheet<_WallpaperSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final modalTheme = Theme.of(context);
        final modalTwainTheme = context.twainTheme;

        return Container(
          decoration: BoxDecoration(
            color: modalTwainTheme.cardBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
            border: context.isDarkMode
                ? Border.all(color: modalTheme.dividerColor, width: 0.6)
                : null,
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: modalTheme.dividerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose wallpaper source',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: modalTheme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSourceTile(
                    theme: modalTheme,
                    icon: Icons.photo_library,
                    title: 'Shared Board',
                    subtitle: 'Pick from the photos you both save.',
                    onTap: () => Navigator.pop(
                      context,
                      _WallpaperSource.sharedBoard,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSourceTile(
                    theme: modalTheme,
                    icon: Icons.phone_android,
                    title: 'From Device',
                    subtitle: 'Choose something from your gallery.',
                    onTap: () => Navigator.pop(
                      context,
                      _WallpaperSource.device,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSourceTile(
                    theme: modalTheme,
                    icon: Icons.explore_outlined,
                    title: 'Browse Unsplash',
                    subtitle: 'Explore curated wallpapers together.',
                    onTap: () => Navigator.pop(
                      context,
                      _WallpaperSource.unsplash,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.7),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
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
          ],
        ),
      ),
    );
  }

  void _openSharedBoard() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SharedBoardScreen(),
      ),
    );
  }

  void _openUnsplashBrowser() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UnsplashBrowserScreen(),
      ),
    );
  }

  Future<void> _pickFromDevice(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final twainTheme = context.twainTheme;

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null && context.mounted) {
        // Navigate to preview/confirmation screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WallpaperPreviewScreen(
              imageFile: File(image.path),
              sourceType: 'device_gallery',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: twainTheme.destructiveColor,
          ),
        );
      }
    }
  }

  // Helper to get appropriate text color for snackbar based on background
  Color _getSnackBarTextColor(Color backgroundColor) {
    // Calculate luminance to determine if background is light or dark
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // Sync a pending wallpaper (force apply)
  Future<void> _syncWallpaper(Wallpaper wallpaper, TwainThemeExtension twainTheme) async {
    final theme = Theme.of(context);
    if (!Platform.isAndroid) {
      final textColor = _getSnackBarTextColor(twainTheme.destructiveBackgroundColor);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Wallpaper can only be applied on Android',
            style: TextStyle(color: textColor),
          ),
          backgroundColor: twainTheme.destructiveBackgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _applyingWallpapers.add(wallpaper.id);
    });

    try {
      // Show loading message
      final loadingBgColor = twainTheme.cardBackgroundColor;
      final loadingTextColor = _getSnackBarTextColor(loadingBgColor);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: twainTheme.iconColor,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Syncing wallpaper...',
                style: TextStyle(color: loadingTextColor),
              ),
            ],
          ),
          duration: const Duration(seconds: 10),
          backgroundColor: loadingBgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: context.isDarkMode
                ? BorderSide(color: theme.dividerColor, width: 0.5)
                : BorderSide.none,
          ),
        ),
      );

      // Apply wallpaper using native Android code
      await WallpaperManagerService.setWallpaper(wallpaper.imageUrl);

      if (!mounted) return;

      // Update status in database
      final service = ref.read(wallpaperServiceProvider);
      await service.markWallpaperApplied(wallpaper.id);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 16),
              const Text(
                'Wallpaper synced successfully!',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: twainTheme.iconColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Update status to failed
      try {
        final service = ref.read(wallpaperServiceProvider);
        await service.markWallpaperFailed(wallpaper.id);
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Failed to sync wallpaper: ${e.toString()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: twainTheme.destructiveColor,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _applyingWallpapers.remove(wallpaper.id);
        });
      }
    }
  }

  // Reapply an already applied wallpaper (creates new record in moments)
  Future<void> _reapplyWallpaper(Wallpaper wallpaper, TwainThemeExtension twainTheme) async {
    final theme = Theme.of(context);
    if (!Platform.isAndroid) {
      final textColor = _getSnackBarTextColor(twainTheme.destructiveBackgroundColor);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Wallpaper can only be applied on Android',
            style: TextStyle(color: textColor),
          ),
          backgroundColor: twainTheme.destructiveBackgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _applyingWallpapers.add(wallpaper.id);
    });

    try {
      // Show loading message
      final loadingBgColor = twainTheme.cardBackgroundColor;
      final loadingTextColor = _getSnackBarTextColor(loadingBgColor);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: twainTheme.iconColor,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Re-applying wallpaper...',
                style: TextStyle(color: loadingTextColor),
              ),
            ],
          ),
          duration: const Duration(seconds: 10),
          backgroundColor: loadingBgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: context.isDarkMode
                ? BorderSide(color: theme.dividerColor, width: 0.5)
                : BorderSide.none,
          ),
        ),
      );

      // Apply wallpaper using native Android code
      await WallpaperManagerService.setWallpaper(wallpaper.imageUrl);

      if (!mounted) return;

      // Create a new reapply record in the database
      final service = ref.read(wallpaperServiceProvider);
      await service.reapplyWallpaper(
        imageUrl: wallpaper.imageUrl,
        originalWallpaperId: wallpaper.id,
      );

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 16),
              const Text(
                'Wallpaper re-applied successfully!',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: twainTheme.iconColor,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Failed to re-apply wallpaper: ${e.toString()}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: twainTheme.destructiveColor,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _applyingWallpapers.remove(wallpaper.id);
        });
      }
    }
  }

  Widget _buildWallpaperHistoryCard(
    BuildContext context,
    Wallpaper wallpaper,
    bool isCurrentUser,
    String currentUserId,
    ThemeData theme,
    TwainThemeExtension twainTheme, {
    bool compact = false,
  }) {
    // Determine button type:
    // - "Sync" for pending wallpapers where current user is the recipient (force sync)
    // - "Reapply" for already applied wallpapers (reuse this wallpaper)
    final isPendingForMe = wallpaper.status == 'pending' &&
        (wallpaper.applyTo == 'both' || wallpaper.senderId != currentUserId);
    final showSyncButton = isPendingForMe && Platform.isAndroid;
    final showReapplyButton = !isPendingForMe && Platform.isAndroid;

    final isApplying = _applyingWallpapers.contains(wallpaper.id);
    final thumbSize = compact ? 52.0 : 60.0;
    final padding = compact ? const EdgeInsets.all(12) : const EdgeInsets.all(16);
    final titleStyle = TextStyle(
      fontSize: compact ? 14 : 16,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );
    final subtitleStyle = TextStyle(
      fontSize: compact ? 12 : 13,
      color: theme.colorScheme.onSurface.withOpacity(0.6),
    );

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WallpaperDetailScreen(
              wallpaper: wallpaper,
              isCurrentUser: isCurrentUser,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: twainTheme.cardBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: compact || context.isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: context.isDarkMode
              ? Border.all(color: theme.dividerColor, width: 0.5)
              : null,
        ),
        child: Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wallpaper thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: buildOptimizedImageUrl(
                  wallpaper.imageUrl,
                  width: 720,
                  quality: 70,
                ),
                cacheManager:
                    TwainCacheManagers.getManager(TwainCacheBucket.wallpaperImages),
                width: thumbSize,
                height: thumbSize,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 60),
                fadeOutDuration: const Duration(milliseconds: 60),
                placeholderFadeInDuration: const Duration(milliseconds: 60),
                useOldImageOnUrlChange: true,
                progressIndicatorBuilder: (context, url, progress) {
                  final value = progress.progress;
                  if (value != null && value >= 1.0) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    width: thumbSize,
                    height: thumbSize,
                    color: theme.colorScheme.surface,
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: value,
                              strokeWidth: 2,
                              color: twainTheme.iconColor,
                            ),
                            if (value != null)
                              Text(
                                '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: twainTheme.iconColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                  errorWidget: (context, url, error) => Container(
                    width: thumbSize,
                    height: thumbSize,
                    color: theme.colorScheme.surface,
                    child: Icon(
                      Icons.image_not_supported,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
              ),

              SizedBox(width: compact ? 12 : 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isCurrentUser ? 'You' : 'Partner',
                          style: titleStyle,
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        Text(
                          wallpaper.sourceType == 'reapply' ? 're-applied' : 'set wallpaper',
                          style: subtitleStyle,
                        ),
                        if (wallpaper.sourceType == 'reapply') ...[
                          SizedBox(width: compact ? 6 : 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 5 : 6,
                              vertical: compact ? 2 : 3,
                            ),
                            decoration: BoxDecoration(
                              color: twainTheme.iconColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.replay,
                                  size: compact ? 10 : 12,
                                  color: twainTheme.iconColor,
                                ),
                                SizedBox(width: compact ? 2 : 3),
                                Text(
                                  'Re-applied',
                                  style: TextStyle(
                                    fontSize: compact ? 9 : 10,
                                    fontWeight: FontWeight.w600,
                                    color: twainTheme.iconColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                    SizedBox(height: compact ? 2 : 4),

                    Text(
                      _getApplyToText(wallpaper.applyTo),
                      style: TextStyle(
                        fontSize: compact ? 11 : 13,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),

                    SizedBox(height: compact ? 6 : 8),

                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: compact ? 13 : 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                        SizedBox(width: compact ? 3 : 4),
                        Text(
                          _formatDateTime(wallpaper.createdAt),
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        SizedBox(width: compact ? 12 : 16),
                        _buildStatusBadge(
                          wallpaper.status,
                          theme,
                          twainTheme,
                          subtle: compact,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sync button - for pending wallpapers (force sync to apply)
              if (showSyncButton)
                Column(
                  children: [
                    SizedBox(height: compact ? 0 : 4),
                    ElevatedButton.icon(
                      onPressed: isApplying
                          ? null
                          : () => _syncWallpaper(wallpaper, twainTheme),
                      icon: isApplying
                          ? const SizedBox.shrink()
                          : Icon(Icons.sync, size: compact ? 14 : 16),
                      label: isApplying
                          ? SizedBox(
                              width: compact ? 14 : 16,
                              height: compact ? 14 : 16,
                              child: CircularProgressIndicator(
                                color: theme.colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Sync',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: twainTheme.iconColor,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 12 : 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: compact ? 0 : 1,
                      ),
                    ),
                  ],
                ),

              // Reapply button - for already applied wallpapers
              if (showReapplyButton)
                Column(
                  children: [
                    SizedBox(height: compact ? 0 : 4),
                    OutlinedButton(
                      onPressed: isApplying
                          ? null
                          : () async {
                              var isTwainPlus = ref.read(isTwainPlusProvider);
                              if (!isTwainPlus) {
                                final purchased = await PaywallScreen.show(
                                  context,
                                  feature: PaywallFeature.wallpaperReapply,
                                );
                                if (!purchased) return;
                                if (!mounted) return;
                                ref.invalidate(subscriptionStatusProvider);
                              }
                              if (!mounted) return;
                              _reapplyWallpaper(wallpaper, twainTheme);
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: twainTheme.iconColor,
                        side: BorderSide(
                          color: twainTheme.iconColor,
                          width: 1.5,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10 : 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isApplying
                          ? SizedBox(
                              width: compact ? 14 : 16,
                              height: compact ? 14 : 16,
                              child: CircularProgressIndicator(
                                color: twainTheme.iconColor,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Reapply',
                                  style: TextStyle(
                                    fontSize: compact ? 12 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (!ref.watch(isTwainPlusProvider)) ...[
                                  SizedBox(width: compact ? 4 : 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: twainTheme.iconColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'PLUS',
                                      style: TextStyle(
                                        fontSize: compact ? 7 : 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    String status,
    ThemeData theme,
    TwainThemeExtension twainTheme, {
    bool subtle = false,
  }) {
    final colorScheme = theme.colorScheme;
    late Color backgroundColor;
    late Color textColor;
    late String label;
    late IconData icon;

    switch (status) {
      case 'applied':
        backgroundColor = colorScheme.secondaryContainer;
        textColor = colorScheme.onSecondaryContainer;
        label = 'Applied';
        icon = Icons.check_circle;
        break;
      case 'pending':
        backgroundColor = colorScheme.tertiaryContainer;
        textColor = colorScheme.onTertiaryContainer;
        label = 'Pending';
        icon = Icons.pending;
        break;
      case 'failed':
        backgroundColor = twainTheme.destructiveBackgroundColor;
        textColor = twainTheme.destructiveColor;
        label = 'Failed';
        icon = Icons.error;
        break;
      default:
        backgroundColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurface.withOpacity(0.7);
        label = status;
        icon = Icons.help;
    }

    if (subtle) {
      return Tooltip(
        message: label,
        child: Icon(
          icon,
          size: 16,
          color: textColor.withOpacity(0.9),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _getApplyToText(String applyTo) {
    switch (applyTo) {
      case 'partner':
        return 'for partner';
      case 'both':
        return 'for both of you';
      default:
        return '';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(dateTime);
    }
  }
}
