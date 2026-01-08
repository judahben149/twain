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

  /// Displays a notification. Optional parameters allow for custom channels and styling.
  static Future<void> showNotification({
    required String title,
    required String body,
    String? channelId,
    String? channelName,
    String? channelDescription,
    String? payload,
    String? color, // Hex string without leading '#'
  }) {
    return _channel.invokeMethod('showNotification', {
      'title': title,
      'body': body,
      if (channelId != null) 'channelId': channelId,
      if (channelName != null) 'channelName': channelName,
      if (channelDescription != null) 'channelDescription': channelDescription,
      if (payload != null) 'payload': payload,
      if (color != null) 'color': color,
    });
  }
}
