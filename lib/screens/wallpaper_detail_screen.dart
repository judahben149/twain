import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/wallpaper.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/providers/wallpaper_providers.dart';
import 'package:twain/services/cache/twain_cache_managers.dart';
import 'package:twain/services/image_download_service.dart';
import 'package:twain/screens/paywall_screen.dart';
import 'package:twain/services/wallpaper_manager_service.dart';

class WallpaperDetailScreen extends ConsumerStatefulWidget {
  final Wallpaper wallpaper;
  final bool isCurrentUser;

  const WallpaperDetailScreen({
    super.key,
    required this.wallpaper,
    required this.isCurrentUser,
  });

  @override
  ConsumerState<WallpaperDetailScreen> createState() => _WallpaperDetailScreenState();
}

class _WallpaperDetailScreenState extends ConsumerState<WallpaperDetailScreen> {
  bool _isApplying = false;
  bool _isDownloading = false;
  Color? _dominantColor;

  @override
  void initState() {
    super.initState();
    _extractPalette();
  }

  Future<void> _extractPalette() async {
    try {
      final imageProvider = CachedNetworkImageProvider(
        widget.wallpaper.imageUrl,
        cacheManager: TwainCacheManagers.getManager(TwainCacheBucket.wallpaperImages),
      );
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(200, 200),
        maximumColorCount: 16,
      );
      if (!mounted) return;
      final color = palette.vibrantColor?.color ??
          palette.dominantColor?.color;
      if (color != null) {
        setState(() => _dominantColor = color);
      }
    } catch (_) {
      // Fallback to theme color — no-op since _dominantColor stays null
    }
  }

  // Helper to get appropriate text color for snackbar based on background
  Color _getSnackBarTextColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // Sync a pending wallpaper (force apply)
  Future<void> _syncWallpaper() async {
    if (!Platform.isAndroid) {
      _showSnackBar('Wallpaper can only be applied on Android', isError: true);
      return;
    }

    setState(() => _isApplying = true);

    try {
      await WallpaperManagerService.setWallpaper(widget.wallpaper.imageUrl);

      // Update status in database
      final service = ref.read(wallpaperServiceProvider);
      await service.markWallpaperApplied(widget.wallpaper.id);

      if (!mounted) return;
      _showSnackBar('Wallpaper synced successfully!');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to sync wallpaper. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  // Reapply an already applied wallpaper (creates new record in moments)
  Future<void> _reapplyWallpaper() async {
    if (!Platform.isAndroid) {
      _showSnackBar('Wallpaper can only be applied on Android', isError: true);
      return;
    }

    // Check for Twain Plus subscription
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

    setState(() => _isApplying = true);

    try {
      await WallpaperManagerService.setWallpaper(widget.wallpaper.imageUrl);

      // Create a new reapply record in the database
      final service = ref.read(wallpaperServiceProvider);
      await service.reapplyWallpaper(
        imageUrl: widget.wallpaper.imageUrl,
        originalWallpaperId: widget.wallpaper.id,
      );

      if (!mounted) return;
      _showSnackBar('Wallpaper re-applied successfully!');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to re-apply wallpaper. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _downloadToGallery() async {
    setState(() => _isDownloading = true);

    try {
      final success = await ImageDownloadService.downloadToGallery(
        widget.wallpaper.imageUrl,
      );

      if (!mounted) return;

      if (success) {
        _showSnackBar('Saved to gallery!');
      } else {
        _showSnackBar('Failed to save image', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to save image. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final twainTheme = context.twainTheme;
    final backgroundColor = isError ? twainTheme.destructiveColor : twainTheme.iconColor;
    final textColor = _getSnackBarTextColor(backgroundColor);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: textColor),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('h:mm a').format(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('h:mm a').format(dateTime)}';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    final senderLabel = widget.isCurrentUser ? 'You' : 'Partner';
    final timestamp = _formatDateTime(widget.wallpaper.appliedAt ?? widget.wallpaper.createdAt);

    // Determine if this is a pending wallpaper for the current user
    final currentUserId = ref.watch(twainUserProvider).value?.id;
    final isPendingForMe = widget.wallpaper.status == 'pending' &&
        (widget.wallpaper.applyTo == 'both' || widget.wallpaper.senderId != currentUserId);

    // Check if this is a re-applied wallpaper
    final isReapplied = widget.wallpaper.sourceType == 'reapply';

    // Button text and icon based on status
    final buttonText = isPendingForMe ? 'Sync Wallpaper' : 'Reapply';
    final buttonIcon = isPendingForMe ? Icons.sync : Icons.replay;
    final loadingText = isPendingForMe ? 'Syncing...' : 'Re-applying...';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen image with pinch-to-zoom
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.wallpaper.imageUrl,
                cacheManager: TwainCacheManagers.getManager(TwainCacheBucket.wallpaperImages),
                fit: BoxFit.contain,
                fadeInDuration: const Duration(milliseconds: 200),
                progressIndicatorBuilder: (context, url, progress) {
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.progress,
                      color: twainTheme.iconColor,
                    ),
                  );
                },
                errorWidget: (context, url, error) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.white.withOpacity(0.5),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load image',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Semi-transparent app bar at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom action bar with gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Metadata
                      Row(
                        children: [
                          Text(
                            isReapplied ? '$senderLabel re-applied' : 'Sent by $senderLabel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isPendingForMe) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: twainTheme.iconColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Pending',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (isReapplied) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: twainTheme.iconColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.replay,
                                    size: 12,
                                    color: twainTheme.iconColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Re-applied',
                                    style: TextStyle(
                                      color: twainTheme.iconColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timestamp,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action buttons
                      Row(
                        children: [
                          // Sync / Reapply button (Android only)
                          if (Platform.isAndroid)
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeOut,
                                child: ElevatedButton.icon(
                                  onPressed: _isApplying
                                      ? null
                                      : (isPendingForMe ? _syncWallpaper : _reapplyWallpaper),
                                  icon: _isApplying
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                        )
                                      : Icon(buttonIcon, size: 20),
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _isApplying ? loadingText : buttonText,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (!isPendingForMe && !_isApplying && !ref.watch(isTwainPlusProvider)) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'PLUS',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: _dominantColor ?? twainTheme.iconColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _dominantColor ?? twainTheme.iconColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (Platform.isAndroid) const SizedBox(width: 12),

                          // Download button
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                              child: OutlinedButton.icon(
                                onPressed: _isDownloading ? null : _downloadToGallery,
                                icon: _isDownloading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.download, size: 20),
                                label: Text(
                                  _isDownloading ? 'Saving...' : 'Download',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: _dominantColor ?? Colors.white,
                                    width: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
