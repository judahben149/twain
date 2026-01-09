import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/wallpaper_folder.dart';
import 'package:twain/models/folder_image.dart';
import 'package:twain/services/folder_service.dart';

/// Provider for FolderService
final folderServiceProvider = Provider<FolderService>((ref) {
  final supabase = Supabase.instance.client;
  return FolderService(supabase: supabase);
});

/// Stream provider for all folders (for the current pair)
final foldersStreamProvider = StreamProvider<List<WallpaperFolder>>((ref) {
  final service = ref.watch(folderServiceProvider);
  return service.streamFolders();
});

/// Stream provider for images in a specific folder
final folderImagesStreamProvider =
    StreamProvider.family<List<FolderImage>, String>(
  (ref, folderId) {
    final service = ref.watch(folderServiceProvider);
    return service.streamFolderImages(folderId);
  },
);

/// Future provider for a single folder by ID
final folderProvider = FutureProvider.family<WallpaperFolder, String>(
  (ref, folderId) async {
    final service = ref.watch(folderServiceProvider);
    return service.getFolder(folderId);
  },
);

/// State provider for selected folder ID (for navigation)
final selectedFolderIdProvider = StateProvider<String?>((ref) => null);
