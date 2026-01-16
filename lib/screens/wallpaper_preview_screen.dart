import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/unsplash_wallpaper.dart';
import 'package:twain/providers/wallpaper_providers.dart';
import 'package:twain/providers/unsplash_providers.dart';
import 'package:twain/services/wallpaper_manager_service.dart';
import 'package:twain/services/cache/twain_cache_managers.dart';
import 'package:twain/utils/image_url_utils.dart';

class WallpaperPreviewScreen extends ConsumerStatefulWidget {
  final String? imageUrl;
  final File? imageFile;
  final String sourceType;
  final UnsplashWallpaper? unsplashWallpaper; // Optional: for Unsplash wallpapers

  const WallpaperPreviewScreen({
    super.key,
    this.imageUrl,
    this.imageFile,
    this.sourceType = 'shared_board',
    this.unsplashWallpaper,
  }) : assert(
          imageUrl != null || imageFile != null,
          'Either imageUrl or imageFile must be provided',
        );

  @override
  ConsumerState<WallpaperPreviewScreen> createState() =>
      _WallpaperPreviewScreenState();
}

class _WallpaperPreviewScreenState
    extends ConsumerState<WallpaperPreviewScreen> {
  late String _applyTo;
  bool _isProcessing = false;
  bool _showApplyOptions = false;

  @override
  void initState() {
    super.initState();
    _applyTo = ref.read(wallpaperApplyToSelectionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    final isDarkMode = context.isDarkMode;
    final previewBackground =
        isDarkMode ? Colors.black : theme.scaffoldBackgroundColor;
    final optimizedPreviewUrl = widget.imageUrl != null
        ? buildOptimizedImageUrl(
            widget.imageUrl!,
            width: 2048,
            quality: 80,
          )
        : null;

    return Scaffold(
      backgroundColor: previewBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor:
            isDarkMode ? Colors.transparent : theme.scaffoldBackgroundColor.withOpacity(0.9),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDarkMode
                ? Colors.white
                : theme.colorScheme.onSurface,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Preview Wallpaper',
          style: TextStyle(
            color: isDarkMode
                ? Colors.white
                : theme.colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Full-screen image preview
          Expanded(
            child: Center(
              child: widget.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: optimizedPreviewUrl!,
                      cacheManager: TwainCacheManagers
                          .getManager(TwainCacheBucket.wallpaperImages),
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 80),
                      fadeOutDuration: const Duration(milliseconds: 80),
                      placeholderFadeInDuration: const Duration(milliseconds: 80),
                      useOldImageOnUrlChange: true,
                      progressIndicatorBuilder: (context, url, progress) {
                        final value = progress.progress;
                        if (value != null && value >= 1.0) {
                          return const SizedBox.shrink();
                        }
                        return Center(
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: value,
                                  color: twainTheme.iconColor,
                                ),
                                if (value != null)
                                  Text(
                                    '${(value * 100).clamp(0, 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: twainTheme.iconColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                      errorWidget: (context, url, error) => Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            color: (isDarkMode
                                    ? Colors.white54
                                    : theme.colorScheme.onSurface)
                                .withOpacity(0.6),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.7)
                                  : theme.colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Image.file(
                      widget.imageFile!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              color: (isDarkMode
                                      ? Colors.white54
                                      : theme.colorScheme.onSurface)
                                  .withOpacity(0.6),
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.7)
                                    : theme.colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),

          // Options panel
          Container(
            decoration: BoxDecoration(
              color: twainTheme.cardBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: isDarkMode
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Set Wallpaper For',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_showApplyOptions)
                      _buildApplyOptions(theme, twainTheme)
                    else
                      _buildApplySummary(theme),

                    const SizedBox(height: 24),

                    // Confirm button
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _confirmSetWallpaper,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: twainTheme.iconColor,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: isDarkMode ? 0 : 2,
                        disabledBackgroundColor: theme.disabledColor,
                      ),
                      child: _isProcessing
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: theme.colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Confirm & Set Wallpaper',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),

                    const SizedBox(height: 8),

                    // Info text
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Text(
                              _applyTo == 'partner'
                                  ? "Only your partner's wallpaper will be changed."
                                  : 'Syncs instantly for you and your partner.',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_applyTo == 'both') ...[
                              const SizedBox(height: 4),
                              Text(
                                'When you apply, the app will restart briefly',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
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

  Widget _buildApplySummary(ThemeData theme) {
    final isBoth = _applyTo == 'both';
    final title = isBoth ? 'Both of Us (recommended)' : 'Just My Partner';
    final subtitle = isBoth
        ? 'Syncs instantly for you and your partner.'
        : "Only your partner's wallpaper will be changed.";

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        trailing: TextButton(
          onPressed: _isProcessing
              ? null
              : () => setState(() {
                    _showApplyOptions = true;
                  }),
          child: const Text('Change'),
        ),
      ),
    );
  }

  Widget _buildApplyOptions(ThemeData theme, TwainThemeExtension twainTheme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            title: Text(
              'Just My Partner',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              "Only your partner's wallpaper will be changed.",
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            value: 'partner',
            groupValue: _applyTo,
            activeColor: twainTheme.iconColor,
            onChanged: _isProcessing
                ? null
                : (value) {
                    if (value == null) return;
                    ref.read(wallpaperApplyToSelectionProvider.notifier).state =
                        value;
                    setState(() {
                      _applyTo = value;
                      _showApplyOptions = false;
                    });
                  },
          ),
          Divider(
            height: 1,
            color: theme.dividerColor,
          ),
          RadioListTile<String>(
            title: Text(
              'Both of Us (recommended)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              'Syncs instantly for you and your partner.',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            value: 'both',
            groupValue: _applyTo,
            activeColor: twainTheme.iconColor,
            onChanged: _isProcessing
                ? null
                : (value) {
                    if (value == null) return;
                    ref.read(wallpaperApplyToSelectionProvider.notifier).state =
                        value;
                    setState(() {
                      _applyTo = value;
                      _showApplyOptions = false;
                    });
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSetWallpaper() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    ref.read(wallpaperApplyToSelectionProvider.notifier).state = _applyTo;

    try {
      final service = ref.read(wallpaperServiceProvider);
      final wallpaperManager = WallpaperManagerService();

      String imageUrl;

      // Handle Unsplash wallpapers - download full resolution first
      if (widget.unsplashWallpaper != null) {
        // Show downloading message
        if (!mounted) return;
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
                const Text('Downloading wallpaper...'),
              ],
            ),
            duration: const Duration(seconds: 30),
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

        // Download full resolution image to temp directory
        final localPath = await wallpaperManager.downloadUnsplashImage(
          widget.unsplashWallpaper!.fullUrl,
          widget.unsplashWallpaper!.id,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Upload to shared board (this makes it accessible to both users)
        if (!mounted) return;
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
                const Text('Uploading photo...'),
              ],
            ),
            duration: const Duration(seconds: 30),
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

        final photo = await service.uploadToSharedBoard(File(localPath));
        imageUrl = photo.imageUrl;

        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Trigger Unsplash download tracking (API requirement)
        ref.read(unsplashProvider.notifier).trackDownload(widget.unsplashWallpaper!);
      }
      // If image is from device (File), upload it first
      else if (widget.imageFile != null) {
        // Show uploading message
        if (!mounted) return;
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
                const Text('Uploading photo...'),
              ],
            ),
            duration: const Duration(seconds: 30),
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

        final photo = await service.uploadToSharedBoard(widget.imageFile!);
        imageUrl = photo.imageUrl;

        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      } else {
        imageUrl = widget.imageUrl!;
      }

      // Set wallpaper (creates record, triggers FCM)
      if (!mounted) return;
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
              const Text('Setting wallpaper...'),
            ],
          ),
          duration: const Duration(seconds: 10),
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

      // Set wallpaper - this may cause Android to restart the app
      // We wrap post-wallpaper code in error handling to gracefully handle app termination
      try {
        await service.setWallpaper(
          imageUrl: imageUrl,
          sourceType: widget.sourceType,
          applyTo: _applyTo,
        );

        // If we reach here, wallpaper was set successfully
        // Note: On Android with applyTo='both', the app may be killed before this code runs
        if (!mounted) return;

        // Dismiss loading snackbar and show success
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.onPrimary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _applyTo == 'partner'
                        ? 'Wallpaper sync initiated! Your partner will be notified.'
                        : 'Wallpaper sync initiated! You both will be notified.',
                  ),
                ),
              ],
            ),
            backgroundColor: twainTheme.iconColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Navigate back to home
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.popUntil(context, (route) => route.isFirst);
      } catch (e) {
        // Check if it's an expected error (app being killed) or a real error
        // If error message contains typical app termination indicators, treat as success
        final errorStr = e.toString().toLowerCase();
        final isAppTermination = errorStr.contains('channel') ||
            errorStr.contains('disposed') ||
            errorStr.contains('unmounted');

        if (isAppTermination) {
          // App was likely killed by Android to apply wallpaper - this is success
          print('App terminated while setting wallpaper (expected behavior)');
          // Don't show error - the wallpaper was set successfully
          return;
        }

        // Real error - rethrow to be handled by outer catch block
        rethrow;
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: theme.colorScheme.onPrimary),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Failed to set wallpaper: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: twainTheme.destructiveColor,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: theme.colorScheme.onPrimary,
            onPressed: _confirmSetWallpaper,
          ),
        ),
      );
    }
  }
}
