import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/shared_board_photo.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/wallpaper_preview_screen.dart';
import 'package:twain/services/cache/twain_cache_managers.dart';
import 'package:twain/services/image_download_service.dart';
import 'package:twain/utils/connectivity_utils.dart';

class SharedBoardPhotoDetailScreen extends ConsumerStatefulWidget {
  final SharedBoardPhoto photo;

  const SharedBoardPhotoDetailScreen({
    super.key,
    required this.photo,
  });

  @override
  ConsumerState<SharedBoardPhotoDetailScreen> createState() =>
      _SharedBoardPhotoDetailScreenState();
}

class _SharedBoardPhotoDetailScreenState
    extends ConsumerState<SharedBoardPhotoDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isDownloading = false;
  bool _showFullRes = false;
  Color? _dominantColor;

  @override
  void initState() {
    super.initState();
    // Defer heavy work until after the Hero animation completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        route.animation!.addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _showFullRes = true);
            _extractPalette();
          }
        });
        // If the animation already completed (e.g. no transition)
        if (route.animation!.isCompleted) {
          setState(() => _showFullRes = true);
          _extractPalette();
        }
      } else {
        setState(() => _showFullRes = true);
        _extractPalette();
      }
    });
  }

  Future<void> _extractPalette() async {
    try {
      // Use thumbnail for palette — it's already cached and sufficient
      final imageProvider = CachedNetworkImageProvider(
        widget.photo.thumbnailUrl ?? widget.photo.imageUrl,
        cacheManager:
            TwainCacheManagers.getManager(TwainCacheBucket.sharedBoardThumbnails),
      );
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(200, 200),
        maximumColorCount: 16,
      );
      if (!mounted) return;
      final color =
          palette.vibrantColor?.color ?? palette.dominantColor?.color;
      if (color != null) {
        setState(() => _dominantColor = color);
      }
    } catch (_) {}
  }

  Future<void> _downloadToGallery() async {
    if (!checkConnectivity(context, ref)) return;

    setState(() => _isDownloading = true);

    try {
      final success =
          await ImageDownloadService.downloadToGallery(widget.photo.imageUrl);

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

  void _setAsWallpaper() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WallpaperPreviewScreen(
          imageUrl: widget.photo.imageUrl,
          sourceType: 'shared_board',
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final twainTheme = context.twainTheme;
    final backgroundColor =
        isError ? twainTheme.destructiveColor : twainTheme.iconColor;
    final luminance = backgroundColor.computeLuminance();
    final textColor = luminance > 0.5 ? Colors.black : Colors.white;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: textColor)),
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
    final twainTheme = context.twainTheme;
    final currentUser = ref.watch(twainUserProvider).value;
    final isCurrentUserPhoto = widget.photo.uploaderId == currentUser?.id;
    final uploaderLabel =
        isCurrentUserPhoto ? 'Uploaded by You' : 'Uploaded by Partner';
    final timestamp = _formatDateTime(widget.photo.createdAt);

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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Hero uses the same thumbnail URL as the grid for smooth animation
                  Hero(
                    tag: 'photo_${widget.photo.id}',
                    child: CachedNetworkImage(
                      imageUrl: widget.photo.thumbnailUrl ?? widget.photo.imageUrl,
                      cacheManager: TwainCacheManagers.getManager(
                          TwainCacheBucket.sharedBoardThumbnails),
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 80),
                    ),
                  ),
                  // Full-res image loads after Hero animation completes
                  if (_showFullRes && widget.photo.thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: widget.photo.imageUrl,
                      cacheManager: TwainCacheManagers.getManager(
                          TwainCacheBucket.sharedBoardThumbnails),
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 300),
                      progressIndicatorBuilder: (context, url, progress) {
                        // Show nothing — thumbnail is visible underneath
                        return const SizedBox.shrink();
                      },
                      errorWidget: (context, url, error) {
                        // Thumbnail is still visible, so no error state needed
                        return const SizedBox.shrink();
                      },
                    ),
                ],
              ),
            ),
          ),

          // Gradient top bar with back button
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Gradient bottom bar
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
                      Text(
                        uploaderLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
                          // Set as Wallpaper button
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _setAsWallpaper,
                              icon: const Icon(Icons.wallpaper, size: 20),
                              label: const Text(
                                'Set as Wallpaper',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _dominantColor ?? twainTheme.iconColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Download button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isDownloading ? null : _downloadToGallery,
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
                                  color:
                                      _dominantColor ?? Colors.white,
                                  width: 2,
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
