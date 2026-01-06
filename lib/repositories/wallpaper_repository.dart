import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/wallpaper.dart';
import 'package:twain/models/shared_board_photo.dart';
import 'package:twain/services/database_service.dart';

class WallpaperRepository {
  final DatabaseService _dbService;
  final SupabaseClient _supabase;

  WallpaperRepository({
    required DatabaseService dbService,
    required SupabaseClient supabase,
  })  : _dbService = dbService,
        _supabase = supabase;

  // Stream wallpapers with cache-first strategy
  Stream<List<Wallpaper>> watchWallpapers(String pairId) async* {
    print('WallpaperRepository: Starting watchWallpapers for pairId: $pairId');

    // Step 1: Immediately yield cached data
    final cachedWallpapers = await _dbService.getWallpapersByPairId(pairId);
    print('WallpaperRepository: Yielding ${cachedWallpapers.length} cached wallpapers');
    yield cachedWallpapers;

    // Step 2: Subscribe to real-time updates
    final controller = StreamController<List<Wallpaper>>.broadcast();

    // Helper function to fetch and emit wallpapers
    Future<void> fetchAndEmit() async {
      try {
        final data = await _supabase
            .from('wallpapers')
            .select()
            .eq('pair_id', pairId)
            .order('created_at', ascending: false);

        print('WallpaperRepository: Fetched ${data.length} wallpapers from Supabase');

        final wallpapers = data.map((json) => Wallpaper.fromJson(json)).toList();
        await _dbService.saveWallpapers(wallpapers);
        print('WallpaperRepository: Updated cache with ${wallpapers.length} wallpapers');

        if (!controller.isClosed) {
          controller.add(wallpapers);
        }
      } catch (e) {
        print('WallpaperRepository: Error fetching wallpapers: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // Subscribe to wallpapers table changes
    _supabase
        .channel('wallpapers_$pairId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'wallpapers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pair_id',
            value: pairId,
          ),
          callback: (payload) {
            print('WallpaperRepository: Wallpapers table changed - ${payload.eventType}');
            fetchAndEmit();
          },
        )
        .subscribe();

    // Initial fetch after subscription
    await fetchAndEmit();

    // Yield from controller stream
    yield* controller.stream;
  }

  // Stream shared board photos with cache-first strategy
  Stream<List<SharedBoardPhoto>> watchSharedBoardPhotos(String pairId) async* {
    print('WallpaperRepository: Starting watchSharedBoardPhotos for pairId: $pairId');

    // Step 1: Immediately yield cached data
    final cachedPhotos = await _dbService.getSharedBoardPhotosByPairId(pairId);
    print('WallpaperRepository: Yielding ${cachedPhotos.length} cached photos');
    yield cachedPhotos;

    // Step 2: Subscribe to real-time updates
    final controller = StreamController<List<SharedBoardPhoto>>.broadcast();

    // Helper function to fetch and emit photos
    Future<void> fetchAndEmit() async {
      try {
        final data = await _supabase
            .from('shared_board_photos')
            .select()
            .eq('pair_id', pairId)
            .order('created_at', ascending: false);

        print('WallpaperRepository: Fetched ${data.length} photos from Supabase');

        final photos = data.map((json) => SharedBoardPhoto.fromJson(json)).toList();
        await _dbService.saveSharedBoardPhotos(photos);
        print('WallpaperRepository: Updated cache with ${photos.length} photos');

        if (!controller.isClosed) {
          controller.add(photos);
        }
      } catch (e) {
        print('WallpaperRepository: Error fetching photos: $e');
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    // Subscribe to shared_board_photos table changes
    _supabase
        .channel('shared_board_photos_$pairId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shared_board_photos',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pair_id',
            value: pairId,
          ),
          callback: (payload) {
            print('WallpaperRepository: Photos table changed - ${payload.eventType}');
            fetchAndEmit();
          },
        )
        .subscribe();

    // Initial fetch after subscription
    await fetchAndEmit();

    // Yield from controller stream
    yield* controller.stream;
  }

  // Cache operations
  Future<List<Wallpaper>> getCachedWallpapers(String pairId) async {
    return await _dbService.getWallpapersByPairId(pairId);
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
    return await _dbService.getSharedBoardPhotosByPairId(pairId);
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
