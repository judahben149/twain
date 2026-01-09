import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:twain/models/wallpaper_folder.dart';
import 'package:twain/models/folder_image.dart';
import 'package:twain/models/unsplash_wallpaper.dart';
import 'package:twain/models/shared_board_photo.dart';

class FolderService {
  final SupabaseClient _supabase;

  FolderService({required SupabaseClient supabase}) : _supabase = supabase;

  User? get currentUser => _supabase.auth.currentUser;

  // Get current user's pair_id
  Future<String?> _getPairId() async {
    final user = currentUser;
    if (user == null) return null;

    final userData = await _supabase
        .from('users')
        .select('pair_id')
        .eq('id', user.id)
        .single();

    return userData['pair_id'] as String?;
  }

  // ==================== FOLDER CRUD OPERATIONS ====================

  /// Create a new wallpaper folder
  Future<WallpaperFolder> createFolder({
    required String name,
    required int rotationIntervalValue,
    required String rotationIntervalUnit,
    required String rotationOrder,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    final pairId = await _getPairId();
    if (pairId == null) throw Exception('No pair found');

    print('Creating folder: $name with interval $rotationIntervalValue $rotationIntervalUnit');

    final response = await _supabase.from('wallpaper_folders').insert({
      'pair_id': pairId,
      'name': name,
      'created_by': user.id,
      'is_active': false, // Start inactive until images are added
      'rotation_interval_value': rotationIntervalValue,
      'rotation_interval_unit': rotationIntervalUnit,
      'rotation_order': rotationOrder,
    }).select().single();

    print('Folder created successfully: ${response['id']}');

    return WallpaperFolder.fromJson(response);
  }

  /// Update folder settings
  Future<WallpaperFolder> updateFolder({
    required String folderId,
    String? name,
    int? rotationIntervalValue,
    String? rotationIntervalUnit,
    String? rotationOrder,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (rotationIntervalValue != null) {
      updates['rotation_interval_value'] = rotationIntervalValue;
    }
    if (rotationIntervalUnit != null) {
      updates['rotation_interval_unit'] = rotationIntervalUnit;
    }
    if (rotationOrder != null) updates['rotation_order'] = rotationOrder;
    if (isActive != null) updates['is_active'] = isActive;

    print('Updating folder $folderId: $updates');

    final response = await _supabase
        .from('wallpaper_folders')
        .update(updates)
        .eq('id', folderId)
        .select()
        .single();

    print('Folder updated successfully');

    return WallpaperFolder.fromJson(response);
  }

  /// Delete a folder (cascade deletes all images)
  Future<void> deleteFolder(String folderId) async {
    print('Deleting folder $folderId');

    await _supabase.from('wallpaper_folders').delete().eq('id', folderId);

    print('Folder deleted successfully');
  }

  /// Get a single folder by ID
  Future<WallpaperFolder> getFolder(String folderId) async {
    final response = await _supabase
        .from('wallpaper_folders')
        .select()
        .eq('id', folderId)
        .single();

    return WallpaperFolder.fromJson(response);
  }

  // ==================== IMAGE MANAGEMENT ====================

  /// Add image from Shared Board to folder
  Future<FolderImage> addImageFromSharedBoard({
    required String folderId,
    required SharedBoardPhoto photo,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    // Get current max position
    final maxPositionResponse = await _supabase
        .from('folder_images')
        .select('position')
        .eq('folder_id', folderId)
        .order('position', ascending: false)
        .limit(1);

    final nextPosition = maxPositionResponse.isEmpty
        ? 0
        : (maxPositionResponse.first['position'] as int) + 1;

    print('Adding shared board image to folder $folderId at position $nextPosition');

    final response = await _supabase.from('folder_images').insert({
      'folder_id': folderId,
      'image_url': photo.imageUrl,
      'source_type': 'shared_board',
      'source_id': photo.id,
      'thumbnail_url': photo.thumbnailUrl,
      'width': photo.width,
      'height': photo.height,
      'position': nextPosition,
      'added_by': user.id,
    }).select().single();

    print('Image added successfully');

    return FolderImage.fromJson(response);
  }

  /// Add image from Device Gallery (after uploading to storage)
  Future<FolderImage> addImageFromDevice({
    required String folderId,
    required File imageFile,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    print('Uploading device image to storage for folder $folderId');

    // Compress image
    final compressed = await FlutterImageCompress.compressWithFile(
      imageFile.absolute.path,
      quality: 85,
      minWidth: 1920,
      minHeight: 1920,
    );

    if (compressed == null) {
      throw Exception('Failed to compress image');
    }

    // Upload to Supabase Storage
    final fileName =
        '${user.id}/folders/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _supabase.storage.from('wallpapers').uploadBinary(fileName, compressed);

    final imageUrl = _supabase.storage.from('wallpapers').getPublicUrl(fileName);

    print('Image uploaded to: $imageUrl');

    // Get current max position
    final maxPositionResponse = await _supabase
        .from('folder_images')
        .select('position')
        .eq('folder_id', folderId)
        .order('position', ascending: false)
        .limit(1);

    final nextPosition = maxPositionResponse.isEmpty
        ? 0
        : (maxPositionResponse.first['position'] as int) + 1;

    final response = await _supabase.from('folder_images').insert({
      'folder_id': folderId,
      'image_url': imageUrl,
      'source_type': 'device_gallery',
      'position': nextPosition,
      'added_by': user.id,
    }).select().single();

    print('Device image added to folder successfully');

    return FolderImage.fromJson(response);
  }

  /// Add image from Unsplash to folder
  Future<FolderImage> addImageFromUnsplash({
    required String folderId,
    required UnsplashWallpaper wallpaper,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    // Get current max position
    final maxPositionResponse = await _supabase
        .from('folder_images')
        .select('position')
        .eq('folder_id', folderId)
        .order('position', ascending: false)
        .limit(1);

    final nextPosition = maxPositionResponse.isEmpty
        ? 0
        : (maxPositionResponse.first['position'] as int) + 1;

    print('Adding Unsplash image to folder $folderId at position $nextPosition');

    final response = await _supabase.from('folder_images').insert({
      'folder_id': folderId,
      'image_url': wallpaper.fullUrl,
      'source_type': 'unsplash',
      'thumbnail_url': wallpaper.smallUrl,
      'width': wallpaper.width,
      'height': wallpaper.height,
      'unsplash_photographer_name': wallpaper.photographerName,
      'unsplash_photographer_username': wallpaper.photographerUsername,
      'unsplash_download_location': wallpaper.downloadLocation,
      'position': nextPosition,
      'added_by': user.id,
    }).select().single();

    print('Unsplash image added successfully');

    return FolderImage.fromJson(response);
  }

  /// Remove image from folder (triggers reindexing via database trigger)
  Future<void> removeImage(String imageId) async {
    print('Removing image $imageId');

    await _supabase.from('folder_images').delete().eq('id', imageId);

    print('Image removed successfully');
  }

  /// Reorder images in folder
  Future<void> reorderImages(String folderId, List<String> imageIdsInOrder) async {
    print('Reordering ${imageIdsInOrder.length} images in folder $folderId');

    // Update each image with its new position
    for (int i = 0; i < imageIdsInOrder.length; i++) {
      await _supabase
          .from('folder_images')
          .update({'position': i})
          .eq('id', imageIdsInOrder[i]);
    }

    print('Images reordered successfully');
  }

  // ==================== STREAMING ====================

  /// Stream all folders for current pair
  Stream<List<WallpaperFolder>> streamFolders() async* {
    final pairId = await _getPairId();
    if (pairId == null) {
      print('No pair_id found, returning empty folder stream');
      yield [];
      return;
    }

    print('Streaming folders for pair: $pairId');

    final stream = _supabase
        .from('wallpaper_folders')
        .stream(primaryKey: ['id'])
        .eq('pair_id', pairId)
        .order('created_at', ascending: false);

    await for (final rows in stream) {
      final folders = rows
          .map((row) => WallpaperFolder.fromJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();
      yield folders;
    }
  }

  /// Stream images for a specific folder
  Stream<List<FolderImage>> streamFolderImages(String folderId) async* {
    print('Streaming images for folder: $folderId');

    final stream = _supabase
        .from('folder_images')
        .stream(primaryKey: ['id'])
        .eq('folder_id', folderId)
        .order('position', ascending: true);

    await for (final rows in stream) {
      final images = rows
          .map((row) => FolderImage.fromJson(
                Map<String, dynamic>.from(row as Map),
              ))
          .toList();
      yield images;
    }
  }

  // ==================== HELPER METHODS ====================

  /// Check if folder can accept more images
  Future<bool> canAddImages(String folderId) async {
    final folder = await getFolder(folderId);
    return folder.canAddImages;
  }

  /// Get total image count for a folder
  Future<int> getImageCount(String folderId) async {
    final response = await _supabase
        .from('folder_images')
        .select('id')
        .eq('folder_id', folderId)
        .count(CountOption.exact);

    return response.count ?? 0;
  }
}
