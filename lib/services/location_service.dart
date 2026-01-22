import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationReading {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  const LocationReading({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'LocationReading(lat: $latitude, lng: $longitude, acc: $accuracy, time: $timestamp)';
  }
}

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  restricted,
  notDetermined,
  unsupported,
}

extension LocationPermissionStatusX on LocationPermissionStatus {
  bool get isGranted => this == LocationPermissionStatus.granted;
  bool get isDenied => this == LocationPermissionStatus.denied;
  bool get isPermanentlyDenied =>
      this == LocationPermissionStatus.deniedForever || this == LocationPermissionStatus.restricted;
}

class LocationService {
  static const _channel = MethodChannel('com.judahben149.twain/location');
  static const _prefDontAskAgain = 'location_permission_dialog_dont_ask';
  static const _prefLastPromptAt = 'location_permission_dialog_last_prompt';
  static const _promptCooldown = Duration(hours: 12);

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  static Future<LocationPermissionStatus> checkPermission() async {
    if (!isSupported) return LocationPermissionStatus.unsupported;

    try {
      final value = await _channel.invokeMethod<String>('checkPermission');
      return _parseStatus(value);
    } on PlatformException catch (e) {
      print('LocationService.checkPermission: $e');
      return LocationPermissionStatus.denied;
    } on MissingPluginException {
      print('LocationService.checkPermission: Missing plugin implementation');
      return LocationPermissionStatus.denied;
    }
  }

  static Future<LocationPermissionStatus> requestPermission() async {
    if (!isSupported) return LocationPermissionStatus.unsupported;

    try {
      final value = await _channel.invokeMethod<String>('requestPermission');
      return _parseStatus(value);
    } on PlatformException catch (e) {
      print('LocationService.requestPermission: $e');
      return LocationPermissionStatus.denied;
    } on MissingPluginException {
      print('LocationService.requestPermission: Missing plugin implementation');
      return LocationPermissionStatus.denied;
    }
  }

  static Future<bool> isLocationEnabled() async {
    if (!isSupported) return false;

    try {
      final enabled = await _channel.invokeMethod<bool>('isLocationEnabled');
      return enabled ?? false;
    } on PlatformException catch (e) {
      print('LocationService.isLocationEnabled: $e');
      return false;
    } on MissingPluginException {
      print('LocationService.isLocationEnabled: Missing plugin implementation');
      return false;
    }
  }

  static Future<LocationReading?> getCurrentLocation() async {
    if (!isSupported) return null;

    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getCurrentLocation');
      if (result == null) return null;

      final latitude = (result['latitude'] as num).toDouble();
      final longitude = (result['longitude'] as num).toDouble();
      final accuracy = (result['accuracy'] as num?)?.toDouble();
      final timestampMs = (result['timestamp'] as num?)?.toInt();
      final timestamp = timestampMs != null
          ? DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true).toLocal()
          : DateTime.now();

      return LocationReading(
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        timestamp: timestamp,
      );
    } on PlatformException catch (e) {
      print('LocationService.getCurrentLocation: $e');
      return null;
    } on MissingPluginException {
      print('LocationService.getCurrentLocation: Missing plugin implementation');
      return null;
    }
  }

  static Future<bool> shouldShowPermissionDialog() async {
    if (!isSupported) return false;

    final prefs = await SharedPreferences.getInstance();
    final dontAskAgain = prefs.getBool(_prefDontAskAgain) ?? false;
    if (dontAskAgain) return false;

    final lastPromptMs = prefs.getInt(_prefLastPromptAt);
    if (lastPromptMs != null) {
      final lastPrompt = DateTime.fromMillisecondsSinceEpoch(lastPromptMs);
      if (DateTime.now().difference(lastPrompt) < _promptCooldown) {
        return false;
      }
    }

    final status = await checkPermission();
    if (status.isGranted || status.isPermanentlyDenied) {
      return false;
    }

    return true;
  }

  static Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLastPromptAt, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> setDontAskAgain(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDontAskAgain, value);
  }

  static LocationPermissionStatus _parseStatus(String? value) {
    switch (value) {
      case 'granted':
        return LocationPermissionStatus.granted;
      case 'denied':
        return LocationPermissionStatus.denied;
      case 'denied_forever':
        return LocationPermissionStatus.deniedForever;
      case 'restricted':
        return LocationPermissionStatus.restricted;
      case 'not_determined':
        return LocationPermissionStatus.notDetermined;
      default:
        return LocationPermissionStatus.denied;
    }
  }
}
