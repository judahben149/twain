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

  /// Saves wallpaper to the iOS App Group container for Siri Shortcuts access.
  static Future<bool> saveWallpaperForShortcuts({
    required String imagePath,
    required String version,
  }) async {
    final result = await _channel.invokeMethod<bool>(
      'saveWallpaperForShortcuts',
      {'imagePath': imagePath, 'version': version},
    );
    return result ?? false;
  }

  /// Returns whether the user has completed the iOS Shortcuts setup flow.
  static Future<bool> getShortcutSetupStatus() async {
    final result = await _channel.invokeMethod<bool>('getShortcutSetupStatus');
    return result ?? false;
  }

  /// Marks the iOS Shortcuts setup as complete.
  static Future<void> markShortcutSetupComplete() {
    return _channel.invokeMethod('markShortcutSetupComplete');
  }

  /// Opens the iOS Shortcuts app.
  static Future<bool> openShortcutsApp() async {
    final result = await _channel.invokeMethod<bool>('openShortcutsApp');
    return result ?? false;
  }

  /// Returns whether a new wallpaper is available that hasn't been applied via Shortcuts.
  static Future<bool> hasNewWallpaper() async {
    final result = await _channel.invokeMethod<bool>('hasNewWallpaper');
    return result ?? false;
  }

  /// Returns diagnostic info about the App Group state (iOS only).
  static Future<Map<String, dynamic>> getDebugInfo() async {
    final result = await _channel.invokeMethod<Map>('getDebugInfo');
    return Map<String, dynamic>.from(result ?? {});
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
