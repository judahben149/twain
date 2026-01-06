import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/wallpaper.dart';
import 'package:twain/models/shared_board_photo.dart';
import 'package:twain/repositories/wallpaper_repository.dart';
import 'package:twain/services/wallpaper_service.dart';
import 'package:twain/services/fcm_service.dart';
import 'package:twain/services/database_service.dart';

// Database service provider (should already exist in auth_providers.dart)
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

// Wallpaper repository provider
final wallpaperRepositoryProvider = Provider<WallpaperRepository>((ref) {
  final supabase = Supabase.instance.client;
  final dbService = ref.watch(databaseServiceProvider);

  return WallpaperRepository(
    dbService: dbService,
    supabase: supabase,
  );
});

// Wallpaper service provider
final wallpaperServiceProvider = Provider<WallpaperService>((ref) {
  final supabase = Supabase.instance.client;
  final repository = ref.watch(wallpaperRepositoryProvider);

  return WallpaperService(
    supabase: supabase,
    repository: repository,
  );
});

// FCM service provider
final fcmServiceProvider = Provider<FCMService>((ref) {
  final supabase = Supabase.instance.client;
  return FCMService(supabase: supabase);
});

// Stream wallpapers
final wallpapersStreamProvider = StreamProvider<List<Wallpaper>>((ref) {
  final service = ref.watch(wallpaperServiceProvider);
  return service.streamWallpapers();
});

// Stream shared board photos
final sharedBoardPhotosStreamProvider = StreamProvider<List<SharedBoardPhoto>>((ref) {
  final service = ref.watch(wallpaperServiceProvider);
  return service.streamSharedBoardPhotos();
});
