import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/shared_board_photo.dart';
import 'package:twain/providers/wallpaper_providers.dart';
import 'package:twain/providers/auth_providers.dart';
import 'package:twain/screens/paywall_screen.dart';
import 'package:twain/screens/wallpaper_preview_screen.dart';
import 'package:twain/services/cache/twain_cache_managers.dart';
import 'package:twain/utils/connectivity_utils.dart';

const int _maxDailyUploads = 1;
const String _dailyUploadsKey = 'shared_board_daily_uploads';
const String _dailyUploadsDateKey = 'shared_board_uploads_date';

class SharedBoardScreen extends ConsumerStatefulWidget {
  const SharedBoardScreen({super.key});

  @override
  ConsumerState<SharedBoardScreen> createState() => _SharedBoardScreenState();
}

class _SharedBoardScreenState extends ConsumerState<SharedBoardScreen> {
  bool _isUploading = false;
  int _todayUploads = 0;
  bool _hasLoadedUploads = false;

  @override
  void initState() {
    super.initState();
    _loadDailyUploads();
  }

  Future<void> _loadDailyUploads() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_dailyUploadsDateKey);
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (storedDate == today) {
      _todayUploads = prefs.getInt(_dailyUploadsKey) ?? 0;
    } else {
      // Reset for new day
      _todayUploads = 0;
      await prefs.setString(_dailyUploadsDateKey, today);
      await prefs.setInt(_dailyUploadsKey, 0);
    }

    if (mounted) {
      setState(() {
        _hasLoadedUploads = true;
      });
    }
  }

  Future<void> _incrementDailyUploads() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(_dailyUploadsDateKey, today);
    _todayUploads++;
    await prefs.setInt(_dailyUploadsKey, _todayUploads);
  }

  bool get _canUploadToday => _todayUploads < _maxDailyUploads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    final photosAsync = ref.watch(sharedBoardPhotosStreamProvider);
    final currentUser = ref.watch(twainUserProvider).value;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Shared Board',
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
      body: photosAsync.when(
        data: (allPhotos) {
          // Filter out wallpaper-sourced photos if preference is off
          final showWallpapers = currentUser?.preferences?['show_wallpapers_in_shared_board'] ?? true;
          final photos = showWallpapers
              ? allPhotos
              : allPhotos.where((p) => p.sourceType != 'wallpaper').toList();

          if (photos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 80,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No photos yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload photos to share with your partner',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildUploadButton(twainTheme),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final photo = photos[index];
              final isCurrentUserPhoto = photo.uploaderId == currentUser?.id;

              return GestureDetector(
                onTap: () => _openPreview(photo),
                onLongPress: isCurrentUserPhoto
                    ? () => _showDeleteDialog(photo, theme, twainTheme)
                    : null,
                child: Hero(
                  tag: 'photo_${photo.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: photo.thumbnailUrl ?? photo.imageUrl,
                            cacheManager: TwainCacheManagers.getManager(
                              TwainCacheBucket.sharedBoardThumbnails,
                            ),
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 80),
                            fadeOutDuration: const Duration(milliseconds: 80),
                            placeholderFadeInDuration: const Duration(milliseconds: 80),
                            useOldImageOnUrlChange: true,
                            progressIndicatorBuilder: (context, url, progress) {
                              return Container(
                                color: theme.colorScheme.surface,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: progress.progress,
                                    color: twainTheme.iconColor,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorWidget: (context, url, error) {
                              return Container(
                                color: theme.colorScheme.surface,
                                child: Icon(
                                  Icons.broken_image,
                                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                                  size: 32,
                                ),
                              );
                            },
                          ),
                          // Indicator for current user's photos
                          if (isCurrentUserPhoto)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 16,
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
                size: 64,
                color: twainTheme.destructiveColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Unable to load photos. Please check your connection and try again.',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Refresh by invalidating the provider
                  ref.invalidate(sharedBoardPhotosStreamProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: twainTheme.iconColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: photosAsync.maybeWhen(
        data: (photos) => photos.isNotEmpty
            ? _buildUploadFab(theme, twainTheme)
            : null,
        orElse: () => null,
      ),
    );
  }

  Widget _buildUploadButton(TwainThemeExtension twainTheme) {
    final isTwainPlus = ref.watch(isTwainPlusProvider);

    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _uploadPhoto,
          icon: const Icon(Icons.add_photo_alternate, size: 24),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Upload Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isTwainPlus) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_todayUploads/$_maxDailyUploads',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: twainTheme.iconColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        if (!isTwainPlus) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              final purchased = await PaywallScreen.show(
                context,
                feature: PaywallFeature.sharedBoardUpload,
              );
              if (purchased) {
                ref.invalidate(subscriptionStatusProvider);
              }
            },
            child: Text(
              'Upgrade for increased uploads',
              style: TextStyle(
                fontSize: 13,
                color: twainTheme.activeStatusTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUploadFab(ThemeData theme, TwainThemeExtension twainTheme) {
    final isTwainPlus = ref.watch(isTwainPlusProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          onPressed: _isUploading ? null : _uploadPhoto,
          backgroundColor: _isUploading
              ? theme.colorScheme.onSurface.withOpacity(0.4)
              : twainTheme.iconColor,
          child: _isUploading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.add, size: 28),
        ),
        if (!isTwainPlus)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: twainTheme.activeStatusTextColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$_todayUploads/$_maxDailyUploads',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openPreview(SharedBoardPhoto photo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WallpaperPreviewScreen(
          imageUrl: photo.imageUrl,
          sourceType: 'shared_board',
        ),
      ),
    );
  }

  Future<void> _uploadPhoto() async {
    if (_isUploading) return;
    if (!checkConnectivity(context, ref)) return;

    // Check for Twain Plus subscription
    var isTwainPlus = ref.read(isTwainPlusProvider);
    if (!isTwainPlus) {
      // Check daily upload limit for free users
      if (!_canUploadToday) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Daily upload limit reached ($_maxDailyUploads/day). Upgrade to Twain Plus for increased uploads!'),
            backgroundColor: context.twainTheme.destructiveColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'Upgrade',
              textColor: Colors.white,
              onPressed: () async {
                final purchased = await PaywallScreen.show(
                  context,
                  feature: PaywallFeature.sharedBoardUpload,
                );
                if (purchased) {
                  ref.invalidate(subscriptionStatusProvider);
                }
              },
            ),
          ),
        );
        return;
      }
    }

    final ImagePicker picker = ImagePicker();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
      });

      if (!mounted) return;

      // Show loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 16),
              Text('Uploading photo...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      final service = ref.read(wallpaperServiceProvider);
      await service.uploadToSharedBoard(File(image.path));

      // Increment daily upload count for free users
      final isTwainPlusNow = ref.read(isTwainPlusProvider);
      if (!isTwainPlusNow) {
        await _incrementDailyUploads();
      }

      if (!mounted) return;

      // Dismiss loading snackbar and show success
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  isTwainPlusNow
                      ? 'Photo uploaded successfully!'
                      : 'Photo uploaded! (${_maxDailyUploads - _todayUploads} uploads remaining today)',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
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
                child: const Text('Upload failed. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showDeleteDialog(SharedBoardPhoto photo, ThemeData theme, TwainThemeExtension twainTheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Photo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this photo from the shared board? This action cannot be undone.',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePhoto(photo);
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: twainTheme.destructiveColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePhoto(SharedBoardPhoto photo) async {
    if (!checkConnectivity(context, ref)) return;

    try {
      // Show loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 16),
              Text('Deleting photo...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      final service = ref.read(wallpaperServiceProvider);
      await service.deletePhoto(photo.id, photo.imageUrl);

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 16),
              Text('Photo deleted successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
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
                child: const Text('Delete failed. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
