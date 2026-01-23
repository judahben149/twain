import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/shared_board_photo.dart';
import 'package:twain/models/wallpaper.dart';
import 'package:twain/services/database_service.dart';

class WallpaperRepository {
  final DatabaseService _dbService;
  final SupabaseClient _supabase;

  WallpaperRepository({
    required DatabaseService dbService,
    required SupabaseClient supabase,
  })  : _dbService = dbService,
        _supabase = supabase;

  Stream<List<Wallpaper>> watchWallpapers(String pairId) async* {
    print('WallpaperRepository: watchWallpapers → pairId=$pairId');

    // Always yield cached data first for offline-first experience
    final cached = await _dbService.getWallpapersByPairId(pairId);
    if (cached.isNotEmpty) {
      print('WallpaperRepository: Emitting ${cached.length} cached wallpapers');
      yield cached;
    } else {
      yield const [];
    }

    // Subscribe to realtime with automatic reconnection on errors
    var shouldReconnect = true;
    while (shouldReconnect) {
      try {
        final stream = _supabase
            .from('wallpapers')
            .stream(primaryKey: ['id'])
            .eq('pair_id', pairId)
            .order('created_at', ascending: false);

        await for (final rows in stream) {
          try {
            final wallpapers = rows
                .map((row) => Wallpaper.fromJson(
                      Map<String, dynamic>.from(row as Map),
                    ))
                .toList();

            print(
                'WallpaperRepository: Realtime update with ${wallpapers.length} wallpapers');
            await _dbService.saveWallpapers(wallpapers);
            yield wallpapers;
          } catch (error) {
            print('WallpaperRepository: Error mapping wallpapers: $error');
            // Continue streaming, don't break the loop
          }
        }
      } catch (error) {
        print('WallpaperRepository: Stream error (token expiry/network): $error');
        // Yield cached data again so UI doesn't show error
        final fallbackCached = await _dbService.getWallpapersByPairId(pairId);
        if (fallbackCached.isNotEmpty) {
          print('WallpaperRepository: Yielding cached data after stream error');
          yield fallbackCached;
        }
        // Wait before retrying
        print('WallpaperRepository: Will retry connection in 5 seconds...');
        await Future.delayed(const Duration(seconds: 5));
        print('WallpaperRepository: Attempting to reconnect...');
      }
    }
  }

  Stream<List<SharedBoardPhoto>> watchSharedBoardPhotos(String pairId) async* {
    print('WallpaperRepository: watchSharedBoardPhotos → pairId=$pairId');

    // Always yield cached data first for offline-first experience
    final cached = await _dbService.getSharedBoardPhotosByPairId(pairId);
    if (cached.isNotEmpty) {
      print(
          'WallpaperRepository: Emitting ${cached.length} cached shared board photos');
      yield cached;
    } else {
      yield const [];
    }

    // Subscribe to realtime with automatic reconnection on errors
    var shouldReconnect = true;
    while (shouldReconnect) {
      try {
        final stream = _supabase
            .from('shared_board_photos')
            .stream(primaryKey: ['id'])
            .eq('pair_id', pairId)
            .order('created_at', ascending: false);

        await for (final rows in stream) {
          try {
            final photos = rows
                .map((row) => SharedBoardPhoto.fromJson(
                      Map<String, dynamic>.from(row as Map),
                    ))
                .toList();

            print(
                'WallpaperRepository: Realtime update with ${photos.length} shared board photos');
            await _dbService.saveSharedBoardPhotos(photos);
            yield photos;
          } catch (error) {
            print('WallpaperRepository: Error mapping shared board photos: $error');
            // Continue streaming, don't break the loop
          }
        }
      } catch (error) {
        print('WallpaperRepository: Shared board stream error: $error');
        // Yield cached data again so UI doesn't show error
        final fallbackCached = await _dbService.getSharedBoardPhotosByPairId(pairId);
        if (fallbackCached.isNotEmpty) {
          print('WallpaperRepository: Yielding cached photos after stream error');
          yield fallbackCached;
        }
        // Wait before retrying
        print('WallpaperRepository: Will retry connection in 5 seconds...');
        await Future.delayed(const Duration(seconds: 5));
        print('WallpaperRepository: Attempting to reconnect...');
      }
    }
  }

  // Cache operations
  Future<List<Wallpaper>> getCachedWallpapers(String pairId) async {
    return _dbService.getWallpapersByPairId(pairId);
  }

  Future<void> cacheWallpapers(List<Wallpaper> wallpapers) async {
    await _dbService.saveWallpapers(wallpapers);
  }

  Future<void> updateWallpaperStatus(String id, String status) async {
    await _dbService.updateWallpaperStatus(id, status);
  }

  Future<void> clearWallpapers() async {
    await _dbService.clearWallpapers();
  }

  Future<List<SharedBoardPhoto>> getCachedPhotos(String pairId) async {
    return _dbService.getSharedBoardPhotosByPairId(pairId);
  }

  Future<void> cachePhotos(List<SharedBoardPhoto> photos) async {
    await _dbService.saveSharedBoardPhotos(photos);
  }

  Future<void> deletePhoto(String id) async {
    await _dbService.deleteSharedBoardPhoto(id);
  }

  Future<void> clearPhotos() async {
    await _dbService.clearSharedBoardPhotos();
  }
}
