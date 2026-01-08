import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:wallpaper_sync_plugin/wallpaper_sync_plugin.dart';

class WallpaperManagerService {
  static Future<void> setWallpaper(String imageUrl) async {
    print('WallpaperManagerService: Setting wallpaper from URL: $imageUrl');

    try {
      // Download image
      print('WallpaperManagerService: Downloading image...');
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode != 200) {
        throw Exception('Failed to download image: ${response.statusCode}');
      }

      final bytes = response.bodyBytes;
      print('WallpaperManagerService: Downloaded ${bytes.length} bytes');

      // Save temporarily
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/wallpaper.jpg');
      await file.writeAsBytes(bytes);

      print('WallpaperManagerService: Saved to temp file: ${file.path}');

      // Call platform method
      await WallpaperSyncPlugin.setWallpaper(file.path);

      print('WallpaperManagerService: Wallpaper set successfully');
    } catch (e) {
      print('WallpaperManagerService: Error: $e');
      throw Exception('Failed to set wallpaper: $e');
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
