import 'dart:async';

import 'package:flutter/services.dart';

/// Internal facade over the native wallpaper sync plugin.
class WallpaperSyncPlugin {
  WallpaperSyncPlugin._();

  static const MethodChannel _channel =
      MethodChannel('com.twain.app/wallpaper');

  /// Pings the native side to verify the channel wiring.
  static Future<String?> ping() => _channel.invokeMethod<String>('ping');

  /// Applies the wallpaper located at [imagePath].
  static Future<void> setWallpaper(String imagePath) {
    return _channel.invokeMethod('setWallpaper', {'imagePath': imagePath});
  }

  /// Displays a notification using the shared wallpaper channel.
  static Future<void> showNotification({
    required String title,
    required String body,
  }) {
    return _channel.invokeMethod('showNotification', {
      'title': title,
      'body': body,
    });
  }
}
