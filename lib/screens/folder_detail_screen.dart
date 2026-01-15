import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:twain/constants/app_themes.dart';
import 'package:twain/models/wallpaper_folder.dart';
import 'package:twain/models/folder_image.dart';
import 'package:twain/providers/folder_providers.dart';
import 'package:twain/screens/create_folder_screen.dart';

class FolderDetailScreen extends ConsumerStatefulWidget {
  final String folderId;

  const FolderDetailScreen({super.key, required this.folderId});

  @override
  ConsumerState<FolderDetailScreen> createState() => _FolderDetailScreenState();
}

class _FolderDetailScreenState extends ConsumerState<FolderDetailScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final folderAsync = ref.watch(folderProvider(widget.folderId));
    final imagesAsync = ref.watch(folderImagesStreamProvider(widget.folderId));

    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: folderAsync.when(
          data: (folder) => Text(
            folder.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        backgroundColor: twainTheme.cardBackgroundColor,
        elevation: context.isDarkMode ? 0 : 1,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Edit button
          IconButton(
            icon: Icon(Icons.edit_outlined, color: theme.colorScheme.onSurface),
            onPressed: () {
              folderAsync.whenData((folder) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateFolderScreen(folder: folder),
                  ),
                );
              });
            },
          ),
          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            onPressed: () {
              folderAsync.whenData((folder) => _confirmDelete(folder));
            },
          ),
        ],
      ),
      body: folderAsync.when(
        data: (folder) => imagesAsync.when(
          data: (images) => _buildContent(folder, images),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, __) => _buildError('Failed to load images: $error'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, __) => _buildError('Failed to load folder: $error'),
      ),
    );
  }

  Widget _buildContent(WallpaperFolder folder, List<FolderImage> images) {
    final theme = Theme.of(context);
    final twainTheme = context.twainTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Card
        _buildHeaderCard(folder, theme, twainTheme),
        const SizedBox(height: 16),

        // Add Images Section
        if (folder.canAddImages) ...[
          _buildAddImagesSection(folder, theme, twainTheme),
          const SizedBox(height: 16),
        ],

        // Images Grid
        if (images.isEmpty)
          _buildEmptyImagesState(theme, twainTheme)
        else
          _buildImagesGrid(images, theme, twainTheme),
      ],
    );
  }

  Widget _buildHeaderCard(
    WallpaperFolder folder,
    ThemeData theme,
    TwainThemeExtension twainTheme,
  ) {
    final isActive = folder.isActive && folder.imageCount > 0;

    return Card(
      elevation: 0,
      color: twainTheme.cardBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: context.isDarkMode
            ? BorderSide(color: theme.dividerColor, width: 0.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Settings Summary
            Row(
              children: [
                Icon(
                  folder.rotationOrder == 'sequential'
                      ? Icons.repeat
                      : Icons.shuffle,
                  size: 18,
                  color: twainTheme.iconColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rotates every ${folder.rotationIntervalDisplay} • ${folder.rotationOrder == 'sequential' ? 'Sequential' : 'Random'}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Image Count
            Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  '${folder.imageCount}/30 images',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(height: 1, color: theme.dividerColor),
            const SizedBox(height: 16),

            // Active Toggle
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Automatic Rotation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        folder.statusText,
                        style: TextStyle(
                          fontSize: 13,
                          color: isActive
                              ? twainTheme.iconColor
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: folder.isActive,
                  onChanged: folder.imageCount > 0
                      ? (value) => _toggleFolderActive(folder, value)
                      : null,
                  activeColor: twainTheme.iconColor,
                ),
              ],
            ),

            if (folder.imageCount == 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withOpacity(0.7),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.error.withOpacity(0.9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add at least 1 image to activate rotation',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.error.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddImagesSection(
    WallpaperFolder folder,
    ThemeData theme,
    TwainThemeExtension twainTheme,
  ) {
    return Card(
      elevation: 0,
      color: twainTheme.cardBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: context.isDarkMode
            ? BorderSide(color: theme.dividerColor, width: 0.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Add Images',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (!folder.canAddImages)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Full 30/30',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.error.withOpacity(0.9),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildAddButton(
                    icon: Icons.grid_on,
                    label: 'Shared Board',
                    onTap: () => _addFromSharedBoard(folder),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAddButton(
                    icon: Icons.phone_android,
                    label: 'Device',
                    onTap: () => _addFromDevice(folder),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildAddButton(
                    icon: Icons.explore_outlined,
                    label: 'Unsplash',
                    onTap: () => _addFromUnsplash(folder),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final twainTheme = context.twainTheme;
    return OutlinedButton(
      onPressed: _isProcessing ? null : onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(color: twainTheme.iconColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: twainTheme.iconColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: twainTheme.iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesGrid(
    List<FolderImage> images,
    ThemeData theme,
    TwainThemeExtension twainTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Images',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            return _buildImageCard(images[index], index, theme, twainTheme);
          },
        ),
      ],
    );
  }

  Widget _buildImageCard(
    FolderImage image,
    int index,
    ThemeData theme,
    TwainThemeExtension twainTheme,
  ) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: context.isDarkMode
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: image.displayUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(
                color: twainTheme.cardBackgroundColor,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: twainTheme.iconColor,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: twainTheme.cardBackgroundColor,
                child: Icon(
                  Icons.broken_image,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ),
        // Position badge
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Delete button
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _confirmDeleteImage(image),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyImagesState(
    ThemeData theme,
    TwainThemeExtension twainTheme,
  ) {
    return Card(
      elevation: 0,
      color: twainTheme.cardBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: context.isDarkMode
            ? BorderSide(color: theme.dividerColor, width: 0.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No Images Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add images from Shared Board, Device, or Unsplash',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _toggleFolderActive(WallpaperFolder folder, bool value) async {
    try {
      await ref.read(folderServiceProvider).updateFolder(
            folderId: folder.id,
            isActive: value,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Folder activated' : 'Folder deactivated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update folder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addFromSharedBoard(WallpaperFolder folder) async {
    // Note: This requires SharedBoardScreen to support selection mode
    // For now, show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shared Board selection coming soon'),
      ),
    );
  }

  Future<void> _addFromDevice(WallpaperFolder folder) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await ref.read(folderServiceProvider).addImageFromDevice(
            folderId: folder.id,
            imageFile: File(pickedFile.path),
          );

      // Refresh folder and images streams to reflect new data immediately
      ref.invalidate(folderProvider(folder.id));
      ref.invalidate(folderImagesStreamProvider(folder.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _addFromUnsplash(WallpaperFolder folder) async {
    // Note: This requires UnsplashBrowserScreen to support selection mode
    // For now, show a message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unsplash selection coming soon'),
      ),
    );
  }

  Future<void> _confirmDeleteImage(FolderImage image) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Image'),
        content: const Text('Are you sure you want to remove this image from the folder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(folderServiceProvider).removeImage(image.id);

      ref.invalidate(folderProvider(image.folderId));
      ref.invalidate(folderImagesStreamProvider(image.folderId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image removed'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDelete(WallpaperFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Folder'),
        content: Text(
          'Are you sure you want to delete "${folder.name}"? This will remove all ${folder.imageCount} images and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(folderServiceProvider).deleteFolder(folder.id);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Folder deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete folder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
