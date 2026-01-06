import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:twain/constants/app_colours.dart';
import 'package:twain/providers/wallpaper_providers.dart';

class WallpaperPreviewScreen extends ConsumerStatefulWidget {
  final String? imageUrl;
  final File? imageFile;
  final String sourceType;

  const WallpaperPreviewScreen({
    super.key,
    this.imageUrl,
    this.imageFile,
    required this.sourceType,
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
  String _applyTo = 'partner';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Preview Wallpaper',
          style: TextStyle(
            color: Colors.white,
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
                  ? Image.network(
                      widget.imageUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : Image.file(
                      widget.imageFile!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load image',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
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
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
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
                          color: Colors.grey.shade300,
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
                        color: Colors.grey.shade800,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Radio buttons
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text(
                              'My Partner',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Only your partner will see this wallpaper',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            value: 'partner',
                            groupValue: _applyTo,
                            activeColor: const Color(0xFFE91E63),
                            onChanged: _isProcessing
                                ? null
                                : (value) => setState(() => _applyTo = value!),
                          ),
                          Divider(
                            height: 1,
                            color: Colors.grey.shade300,
                          ),
                          RadioListTile<String>(
                            title: const Text(
                              'Both of Us',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'You and your partner will both see this wallpaper',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            value: 'both',
                            groupValue: _applyTo,
                            activeColor: const Color(0xFFE91E63),
                            onChanged: _isProcessing
                                ? null
                                : (value) => setState(() => _applyTo = value!),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Confirm button
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _confirmSetWallpaper,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
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
                        child: Text(
                          _applyTo == 'partner'
                              ? 'Your partner will receive a notification to apply the wallpaper'
                              : 'Both you and your partner will receive a notification',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
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

  Future<void> _confirmSetWallpaper() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final service = ref.read(wallpaperServiceProvider);

      String imageUrl;

      // If image is from device (File), upload it first
      if (widget.imageFile != null) {
        // Show uploading message
        if (!mounted) return;
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
              Text('Setting wallpaper...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      await service.setWallpaper(
        imageUrl: imageUrl,
        sourceType: widget.sourceType,
        applyTo: _applyTo,
      );

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
                  _applyTo == 'partner'
                      ? 'Wallpaper sync initiated! Your partner will be notified.'
                      : 'Wallpaper sync initiated! You both will be notified.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate back to home (pop all screens until first route)
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
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
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Failed to set wallpaper: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: _confirmSetWallpaper,
          ),
        ),
      );
    }
  }
}
