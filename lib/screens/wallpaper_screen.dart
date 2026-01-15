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
import 'package:twain/services/wallpaper_manager_service.dart';
import 'package:twain/services/cache/twain_cache_managers.dart';
import 'package:twain/utils/image_url_utils.dart';

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
      ),
      body: Column(
        children: [
          // Action buttons section
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: twainTheme.cardBackgroundColor,
              boxShadow: context.isDarkMode
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
              border: context.isDarkMode
                  ? Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5))
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Change Wallpaper',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),

                // Shared Board Button
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SharedBoardScreen(),
                    ),
                  ),
                  icon: Icon(
                    Icons.photo_library,
                    size: 22,
                    color: theme.colorScheme.onPrimary,
                  ),
                  label: Text(
                    'Choose from Shared Board',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: twainTheme.iconColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),

                const SizedBox(height: 12),

                // Device Gallery Button
                OutlinedButton.icon(
                  onPressed: () => _pickFromDevice(context),
                  icon: Icon(Icons.phone_android, size: 22, color: twainTheme.iconColor),
                  label: Text(
                    'Choose from Device',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: twainTheme.iconColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: twainTheme.iconColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: twainTheme.iconColor,
                      width: 2,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Browse Wallpapers Button (Unsplash)
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UnsplashBrowserScreen(),
                    ),
                  ),
                  icon: Icon(
                    Icons.explore_outlined,
                    size: 22,
                    color: theme.colorScheme.onPrimary,
                  ),
                  label: Text(
                    'Browse Wallpapers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: twainTheme.iconColor,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),

                const SizedBox(height: 12),

                // Rotation Folders Button
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FoldersListScreen(),
                    ),
                  ),
                  icon: Icon(
                    Icons.folder_outlined,
                    size: 22,
                    color: twainTheme.activeStatusTextColor,
                  ),
                  label: Text(
                    'Rotation Folders',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: twainTheme.activeStatusTextColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: twainTheme.activeStatusTextColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: twainTheme.activeStatusTextColor,
                      width: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Recent wallpaper changes header
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Icon(
                  Icons.history,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          // Recent wallpaper changes list
          Expanded(
            child: wallpapersAsync.when(
              data: (wallpapers) {
                if (wallpapers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wallpaper_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No wallpaper changes yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Set a wallpaper to get started!',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  itemCount: wallpapers.length,
                  itemBuilder: (context, index) {
                    final wallpaper = wallpapers[index];
                    final isCurrentUser = wallpaper.senderId == currentUser?.id;
                    return _buildWallpaperHistoryCard(
                      context,
                      wallpaper,
                      isCurrentUser,
                      currentUser?.id ?? '',
                      theme,
                      twainTheme,
                    );
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: twainTheme.iconColor,
                ),
              ),
              error: (error, stack) => Center(
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
                    Text(
                      '$error',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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

  Future<void> _applyWallpaper(Wallpaper wallpaper, TwainThemeExtension twainTheme) async {
    final theme = Theme.of(context);
    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Wallpaper can only be applied on Android'),
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
              SizedBox(width: 16),
              Text('Applying wallpaper...'),
            ],
          ),
          duration: Duration(seconds: 10),
          backgroundColor: twainTheme.cardBackgroundColor,
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
              Icon(Icons.check_circle, color: theme.colorScheme.onPrimary),
              const SizedBox(width: 16),
              const Text('Wallpaper applied successfully!'),
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

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: theme.colorScheme.onPrimary),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Failed to apply wallpaper: ${e.toString()}'),
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
    TwainThemeExtension twainTheme,
  ) {
    // Determine if current user should see the Apply button
    final shouldShowApply = wallpaper.status == 'pending' &&
        (wallpaper.applyTo == 'both' || wallpaper.senderId != currentUserId) &&
        Platform.isAndroid;

    final isApplying = _applyingWallpapers.contains(wallpaper.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: twainTheme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
        border: context.isDarkMode
            ? Border.all(color: theme.dividerColor, width: 0.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
              width: 60,
              height: 60,
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
                  width: 60,
                  height: 60,
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
                  width: 60,
                  height: 60,
                  color: theme.colorScheme.surface,
                  child: Icon(
                    Icons.image_not_supported,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isCurrentUser ? 'You' : 'Partner',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'set wallpaper',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _getApplyToText(wallpaper.applyTo),
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(wallpaper.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildStatusBadge(
                        wallpaper.status,
                        theme,
                        twainTheme,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Apply button (only on Android for pending wallpapers)
            if (shouldShowApply)
              Column(
                children: [
                  const SizedBox(height: 4),
                  ElevatedButton(
                    onPressed: isApplying
                        ? null
                        : () => _applyWallpaper(wallpaper, twainTheme),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: twainTheme.iconColor,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                    ),
                    child: isApplying
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Apply',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    String status,
    ThemeData theme,
    TwainThemeExtension twainTheme,
  ) {
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
