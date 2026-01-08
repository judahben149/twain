import 'dart:io';
import 'dart:isolate';
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

class WallpaperManagerService {
  /// Set wallpaper from URL (downloads and applies)
  /// Note: On Android, this may cause the app to restart
  static Future<void> setWallpaper(String imageUrl) async {
    print('WallpaperManagerService: Setting wallpaper from URL: $imageUrl');

    try {
      // Get temp directory path first (must be done on main isolate)
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Download image in background isolate to avoid blocking main thread
      print('WallpaperManagerService: Downloading image in background...');
      await compute(_downloadImageInBackground, _DownloadImageTask(imageUrl, filePath));

      final bytes = await File(filePath).length();
      print('WallpaperManagerService: Downloaded ${bytes} bytes');

      print('WallpaperManagerService: Applying wallpaper...');

      // Call platform method - this may cause Android to kill the app
      // Any code after this might not execute if app is killed
      await WallpaperSyncPlugin.setWallpaper(filePath);

      print('WallpaperManagerService: Wallpaper set successfully');

      // Clean up temp file after a delay (in case app is killed, this won't run)
      Future.delayed(const Duration(seconds: 2), () {
        try {
          File(filePath).deleteSync();
        } catch (e) {
          print('Failed to delete temp file: $e');
        }
      });
    } catch (e) {
      print('WallpaperManagerService: Error: $e');
      throw Exception('Failed to set wallpaper: $e');
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
