import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to handle battery optimization checks and requests.
/// Only relevant on Android 6.0 (API 23) and above.
class BatteryOptimizationService {
  static const _channel = MethodChannel('com.judahben149.twain/battery');
  static const _prefKeyDismissed = 'battery_optimization_dialog_dismissed';
  static const _prefKeyDismissedAt = 'battery_optimization_dialog_dismissed_at';

  /// Check if we're on Android (battery optimization only applies to Android)
  static bool get isAndroid => Platform.isAndroid;

  /// Check if battery optimization is disabled for this app.
  /// Returns true if unrestricted, false if optimized, null if not applicable.
  static Future<bool?> isIgnoringBatteryOptimizations() async {
    if (!isAndroid) return null;

    try {
      final result = await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return result;
    } on PlatformException catch (e) {
      print('BatteryOptimizationService: Error checking status: $e');
      return null;
    } on MissingPluginException {
      print('BatteryOptimizationService: Plugin not implemented');
      return null;
    }
  }

  /// Open the battery optimization settings for this app.
  /// Returns true if settings were opened successfully.
  static Future<bool> openBatteryOptimizationSettings() async {
    if (!isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      print('BatteryOptimizationService: Error opening settings: $e');
      return false;
    } on MissingPluginException {
      print('BatteryOptimizationService: Plugin not implemented');
      return false;
    }
  }

  /// Request to ignore battery optimizations directly (shows system dialog).
  /// Note: This requires REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission.
  /// Returns true if request was successful or user granted permission.
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
      return result ?? false;
    } on PlatformException catch (e) {
      print('BatteryOptimizationService: Error requesting: $e');
      return false;
    } on MissingPluginException {
      print('BatteryOptimizationService: Plugin not implemented');
      return false;
    }
  }

  /// Check if user has dismissed the dialog and chosen not to be reminded.
  static Future<bool> hasUserDismissedDialog() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyDismissed) ?? false;
  }

  /// Mark the dialog as dismissed by user.
  static Future<void> setDialogDismissed(bool dismissed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyDismissed, dismissed);
    if (dismissed) {
      await prefs.setInt(_prefKeyDismissedAt, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Reset the dismissal (useful if we want to remind again after some time).
  static Future<void> resetDismissal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyDismissed);
    await prefs.remove(_prefKeyDismissedAt);
  }

  /// Check if we should show the battery optimization dialog.
  /// Returns true if:
  /// - We're on Android
  /// - Battery optimization is NOT disabled
  /// - User hasn't permanently dismissed the dialog
  static Future<bool> shouldShowDialog() async {
    if (!isAndroid) return false;

    final isDismissed = await hasUserDismissedDialog();
    if (isDismissed) return false;

    final isIgnoring = await isIgnoringBatteryOptimizations();
    // Show dialog if we're NOT ignoring battery optimizations
    return isIgnoring == false;
  }
}
