import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_sync_plugin/wallpaper_sync_plugin.dart';

/// Helper class for downloading images in background isolate
class _DownloadImageTask {
  final String url;
  final String savePath;

  _DownloadImageTask(this.url, this.savePath);
}

/// Background isolate function for downloading image
Future<void> _downloadImageInBackground(_DownloadImageTask task) async {
  final response = await http.get(Uri.parse(task.url));
  if (response.statusCode == 200) {
    await File(task.savePath).writeAsBytes(response.bodyBytes);
  } else {
    throw Exception('Failed to download: ${response.statusCode}');
  }
}

/// Maximum number of cached wallpapers to keep
const int _maxCachedWallpapers = 50;

/// Cache directory name
const String _wallpaperCacheDir = 'wallpaper_cache';

class WallpaperManagerService {
  /// Get the wallpaper cache directory
  static Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_wallpaperCacheDir');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Generate a unique filename from URL using MD5 hash
  static String _getCacheFilename(String url) {
    final hash = md5.convert(utf8.encode(url)).toString();
    return 'wallpaper_$hash.jpg';
  }

  /// Check if a wallpaper is already cached
  static Future<String?> _getCachedPath(String imageUrl) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final filename = _getCacheFilename(imageUrl);
      final cachedFile = File('${cacheDir.path}/$filename');

      if (await cachedFile.exists()) {
        final bytes = await cachedFile.length();
        if (bytes > 0) {
          print('WallpaperManagerService: Found cached wallpaper: ${cachedFile.path} (${bytes} bytes)');
          return cachedFile.path;
        }
      }
    } catch (e) {
      print('WallpaperManagerService: Error checking cache: $e');
    }
    return null;
  }

  /// Save wallpaper to cache
  static Future<String> _saveToCache(String imageUrl, String tempPath) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final filename = _getCacheFilename(imageUrl);
      final cachePath = '${cacheDir.path}/$filename';

      // Copy from temp to cache
      await File(tempPath).copy(cachePath);
      print('WallpaperManagerService: Saved to cache: $cachePath');

      // Clean up old cache entries if needed
      _cleanupCacheIfNeeded(cacheDir);

      return cachePath;
    } catch (e) {
      print('WallpaperManagerService: Error saving to cache: $e');
      return tempPath; // Return temp path as fallback
    }
  }

  /// Clean up old cache entries to prevent unlimited growth
  static Future<void> _cleanupCacheIfNeeded(Directory cacheDir) async {
    try {
      final files = await cacheDir.list().toList();
      if (files.length <= _maxCachedWallpapers) return;

      // Sort by modified time (oldest first)
      final fileStats = <File, DateTime>{};
      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          fileStats[entity] = stat.modified;
        }
      }

      final sortedFiles = fileStats.keys.toList()
        ..sort((a, b) => fileStats[a]!.compareTo(fileStats[b]!));

      // Delete oldest files until we're under the limit
      final toDelete = sortedFiles.length - _maxCachedWallpapers;
      for (var i = 0; i < toDelete; i++) {
        await sortedFiles[i].delete();
        print('WallpaperManagerService: Deleted old cache: ${sortedFiles[i].path}');
      }
    } catch (e) {
      print('WallpaperManagerService: Error cleaning cache: $e');
    }
  }

  /// Set wallpaper from URL (uses cache if available, otherwise downloads)
  /// Note: On Android, this may cause the app to restart
  static Future<void> setWallpaper(String imageUrl) async {
    print('WallpaperManagerService: ========== WALLPAPER SET START ==========');
    print('WallpaperManagerService: URL: $imageUrl');

    try {
      String filePath;

      // Check if wallpaper is already cached
      final cachedPath = await _getCachedPath(imageUrl);

      if (cachedPath != null) {
        // Use cached version - saves bandwidth!
        print('WallpaperManagerService: Using CACHED wallpaper (no download needed)');
        filePath = cachedPath;
      } else {
        // Download to temp first, then cache
        print('WallpaperManagerService: Wallpaper not cached, downloading...');
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/wallpaper_temp_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await compute(_downloadImageInBackground, _DownloadImageTask(imageUrl, tempPath));

        final tempFile = File(tempPath);
        final bytes = await tempFile.length();
        print('WallpaperManagerService: Downloaded ${bytes} bytes');

        // Save to persistent cache
        filePath = await _saveToCache(imageUrl, tempPath);

        // Delete temp file
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      final file = File(filePath);
      final bytes = await file.length();
      print('WallpaperManagerService: Applying wallpaper from: $filePath (${bytes} bytes)');

      // Call platform method - this may cause Android to kill the app
      await WallpaperSyncPlugin.setWallpaper(filePath);

      print('WallpaperManagerService: Wallpaper set successfully');
      print('WallpaperManagerService: ========== WALLPAPER SET END ==========');
    } catch (e) {
      print('WallpaperManagerService: Error: $e');
      print('WallpaperManagerService: ========== WALLPAPER SET FAILED ==========');
      throw Exception('Failed to set wallpaper: $e');
    }
  }

  /// Clear the wallpaper cache
  static Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('WallpaperManagerService: Cache cleared');
      }
    } catch (e) {
      print('WallpaperManagerService: Error clearing cache: $e');
    }
  }

  /// Get cache size in bytes
  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      int totalSize = 0;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Download Unsplash image to temporary directory (in background isolate)
  /// Returns the local file path
  Future<String> downloadUnsplashImage(String url, String id) async {
    print('WallpaperManagerService: Downloading Unsplash image from: $url');

    try {
      // Get temp directory path first (must be done on main isolate)
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/unsplash_$id.jpg';

      // Download in background to avoid blocking main thread
      await compute(_downloadImageInBackground, _DownloadImageTask(url, filePath));

      final bytes = await File(filePath).length();
      print('WallpaperManagerService: Downloaded ${bytes} bytes to: $filePath');

      return filePath;
    } catch (e) {
      print('WallpaperManagerService: Error downloading Unsplash image: $e');
      throw Exception('Failed to download wallpaper: $e');
    }
  }

  // Test method to check if the platform channel is available
  static Future<bool> isAvailable() async {
    try {
      await WallpaperSyncPlugin.ping();
      return true;
    } on PlatformException catch (e) {
      print('WallpaperManagerService: Platform channel not available: $e');
      return false;
    } on MissingPluginException catch (e) {
      print('WallpaperManagerService: Platform implementation missing: $e');
      return false;
    }
  }
}
