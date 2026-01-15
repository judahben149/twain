import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:twain/constants/app_colours.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: folderAsync.when(
          data: (folder) => Text(
            folder.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.black,
            ),
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Error'),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.black),
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
            icon: const Icon(Icons.delete_outline, color: Colors.red),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Card
        _buildHeaderCard(folder),
        const SizedBox(height: 16),

        // Add Images Section
        if (folder.canAddImages) ...[
          _buildAddImagesSection(folder),
          const SizedBox(height: 16),
        ],

        // Images Grid
        if (images.isEmpty)
          _buildEmptyImagesState()
        else
          _buildImagesGrid(images),
      ],
    );
  }

  Widget _buildHeaderCard(WallpaperFolder folder) {
    final isActive = folder.isActive && folder.imageCount > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  color: const Color(0xFFE91E63),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rotates every ${folder.rotationIntervalDisplay} • ${folder.rotationOrder == 'sequential' ? 'Sequential' : 'Random'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Image Count
            Row(
              children: [
                Icon(Icons.photo_library_outlined, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${folder.imageCount}/30 images',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Active Toggle
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Automatic Rotation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        folder.statusText,
                        style: TextStyle(
                          fontSize: 13,
                          color: isActive ? const Color(0xFFE91E63) : Colors.grey[600],
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
                  activeColor: const Color(0xFFE91E63),
                ),
              ],
            ),

            if (folder.imageCount == 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add at least 1 image to activate rotation',
                        style: TextStyle(fontSize: 12, color: Colors.orange[700]),
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

  Widget _buildAddImagesSection(WallpaperFolder folder) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Add Images',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                const Spacer(),
                if (!folder.canAddImages)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Full 30/30',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
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
    return OutlinedButton(
      onPressed: _isProcessing ? null : onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: Color(0xFFE91E63)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: const Color(0xFFE91E63)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFE91E63),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesGrid(List<FolderImage> images) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Images',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.black,
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
            return _buildImageCard(images[index], index);
          },
        ),
      ],
    );
  }

  Widget _buildImageCard(FolderImage image, int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
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
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.broken_image, color: Colors.grey),
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
                color: Colors.red.withOpacity(0.9),
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

  Widget _buildEmptyImagesState() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Images Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add images from Shared Board, Device, or Unsplash',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
