import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:twain/models/wallpaper.dart';
import 'package:twain/models/shared_board_photo.dart';
import 'package:twain/repositories/wallpaper_repository.dart';
import 'package:twain/services/wallpaper_manager_service.dart';

class WallpaperService {
  final SupabaseClient _supabase;
  final WallpaperRepository? _repository;

  WallpaperService({
    required SupabaseClient supabase,
    WallpaperRepository? repository,
  })  : _supabase = supabase,
        _repository = repository;

  // Get current user
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

  // Upload photo to shared board
  Future<SharedBoardPhoto> uploadToSharedBoard(File imageFile) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    // Get pair_id
    final userData = await _supabase
        .from('users')
        .select('pair_id')
        .eq('id', user.id)
        .single();
    final pairId = userData['pair_id'] as String?;
    if (pairId == null) throw Exception('No pair found');

    print('Uploading image to shared board for pair: $pairId');

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
    final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _supabase.storage
        .from('wallpapers')
        .uploadBinary(fileName, compressed);

    final imageUrl = _supabase.storage
        .from('wallpapers')
        .getPublicUrl(fileName);

    print('Image uploaded to: $imageUrl');

    // Create database record
    final photoData = await _supabase.from('shared_board_photos').insert({
      'pair_id': pairId,
      'uploader_id': user.id,
      'image_url': imageUrl,
      'file_size': compressed.length,
      'mime_type': 'image/jpeg',
    }).select().single();

    print('Shared board photo record created');

    return SharedBoardPhoto.fromJson(photoData);
  }

  // Set wallpaper (creates wallpaper record, triggers FCM)
  Future<void> setWallpaper({
    required String imageUrl,
    required String sourceType,
    required String applyTo,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    final userData = await _supabase
        .from('users')
        .select('pair_id')
        .eq('id', user.id)
        .single();
    final pairId = userData['pair_id'] as String?;
    if (pairId == null) throw Exception('No pair found');

    print('Setting wallpaper for pair: $pairId');
    print('Image URL: $imageUrl');
    print('Source: $sourceType, Apply to: $applyTo');

    // Create wallpaper record (triggers Edge Function → FCM)
    final inserted = await _supabase.from('wallpapers').insert({
      'pair_id': pairId,
      'sender_id': user.id,
      'image_url': imageUrl,
      'source_type': sourceType,
      'apply_to': applyTo,
      'status': 'pending',
    }).select().single();

    final wallpaper = Wallpaper.fromJson(inserted);

    final shouldApplyLocally = Platform.isAndroid && applyTo != 'partner';
    if (shouldApplyLocally) {
      try {
        await WallpaperManagerService.setWallpaper(imageUrl);
        print('WallpaperService: Applied wallpaper locally for sender device');
      } catch (e) {
        print('WallpaperService: Failed to apply wallpaper locally: $e');
      }
    }

    print('Wallpaper record created, FCM notification will be triggered');
  }

  // Reapply an existing wallpaper (creates a new record in moments list)
  Future<void> reapplyWallpaper({
    required String imageUrl,
    required String originalWallpaperId,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    final userData = await _supabase
        .from('users')
        .select('pair_id')
        .eq('id', user.id)
        .single();
    final pairId = userData['pair_id'] as String?;
    if (pairId == null) throw Exception('No pair found');

    print('Reapplying wallpaper for pair: $pairId');
    print('Image URL: $imageUrl');
    print('Original wallpaper ID: $originalWallpaperId');

    // Create new wallpaper record with source_type 'reapply'
    await _supabase.from('wallpapers').insert({
      'pair_id': pairId,
      'sender_id': user.id,
      'image_url': imageUrl,
      'source_type': 'reapply',
      'apply_to': 'both', // Reapply is always for the current user only effectively
      'status': 'applied', // Already applied since we're reapplying
      'applied_at': DateTime.now().toIso8601String(),
    }).select().single();

    print('Reapply wallpaper record created');
  }

  // Mark wallpaper as applied
  Future<void> markWallpaperApplied(String wallpaperId) async {
    print('Marking wallpaper $wallpaperId as applied');

    await _supabase.from('wallpapers').update({
      'status': 'applied',
      'applied_at': DateTime.now().toIso8601String(),
    }).eq('id', wallpaperId);

    // Also update local cache if repository is available
    if (_repository != null) {
      await _repository.updateWallpaperStatus(wallpaperId, 'applied');
    }

    print('Wallpaper marked as applied');
  }

  // Mark wallpaper as failed
  Future<void> markWallpaperFailed(String wallpaperId) async {
    print('Marking wallpaper $wallpaperId as failed');

    await _supabase.from('wallpapers').update({
      'status': 'failed',
    }).eq('id', wallpaperId);

    // Also update local cache if repository is available
    if (_repository != null) {
      await _repository.updateWallpaperStatus(wallpaperId, 'failed');
    }

    print('Wallpaper marked as failed');
  }

  // Delete photo from shared board
  Future<void> deletePhoto(String photoId, String imageUrl) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    print('Deleting photo $photoId from shared board');

    // Delete from storage
    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      // Path format: /storage/v1/object/public/wallpapers/{userId}/{filename}
      if (pathSegments.length >= 6) {
        final filePath = '${pathSegments[5]}/${pathSegments[6]}';
        await _supabase.storage.from('wallpapers').remove([filePath]);
        print('File deleted from storage: $filePath');
      }
    } catch (e) {
      print('Error deleting file from storage: $e');
      // Continue even if storage deletion fails
    }

    // Delete from database
    await _supabase.from('shared_board_photos').delete().eq('id', photoId);

    // Also delete from local cache if repository is available
    if (_repository != null) {
      await _repository.deletePhoto(photoId);
    }

    print('Photo deleted from shared board');
  }

  // Stream operations
  Stream<List<Wallpaper>> streamWallpapers() async* {
    final pairId = await _getPairId();
    if (pairId == null) {
      print('No pair_id found, returning empty stream');
      yield [];
      return;
    }

    print('Streaming wallpapers for pair: $pairId');

    if (_repository != null) {
      yield* _repository.watchWallpapers(pairId);
    } else {
      // Fallback to direct Supabase (without repository)
      print('WallpaperService: No repository, using direct Supabase');

      final controller = StreamController<List<Wallpaper>>();

      Future<List<Wallpaper>> fetchWallpapers() async {
        final data = await _supabase
            .from('wallpapers')
            .select()
            .eq('pair_id', pairId)
            .order('created_at', ascending: false);

        return data.map((json) => Wallpaper.fromJson(json)).toList();
      }

      _supabase.channel('wallpapers_$pairId').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'wallpapers',
        callback: (payload) async {
          controller.add(await fetchWallpapers());
        },
      ).subscribe();

      controller.add(await fetchWallpapers());

      await for (final wallpapers in controller.stream) {
        yield wallpapers;
      }
    }
  }

  Stream<List<SharedBoardPhoto>> streamSharedBoardPhotos() async* {
    final pairId = await _getPairId();
    if (pairId == null) {
      print('No pair_id found, returning empty stream');
      yield [];
      return;
    }

    print('Streaming shared board photos for pair: $pairId');

    if (_repository != null) {
      yield* _repository.watchSharedBoardPhotos(pairId);
    } else {
      // Fallback to direct Supabase (without repository)
      print('WallpaperService: No repository, using direct Supabase');

      final controller = StreamController<List<SharedBoardPhoto>>();

      Future<List<SharedBoardPhoto>> fetchPhotos() async {
        final data = await _supabase
            .from('shared_board_photos')
            .select()
            .eq('pair_id', pairId)
            .order('created_at', ascending: false);

        return data.map((json) => SharedBoardPhoto.fromJson(json)).toList();
      }

      _supabase.channel('shared_board_photos_$pairId').onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shared_board_photos',
        callback: (payload) async {
          controller.add(await fetchPhotos());
        },
      ).subscribe();

      controller.add(await fetchPhotos());

      await for (final photos in controller.stream) {
        yield photos;
      }
    }
  }
}
