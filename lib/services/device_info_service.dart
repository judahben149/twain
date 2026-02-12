import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoService {
  static final _deviceInfo = DeviceInfoPlugin();

  static Future<Map<String, dynamic>> getDeviceMetadata() async {
    final timezone = _getTimezoneInfo();

    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return {
        'device_platform': 'android',
        'device_model': '${info.manufacturer} ${info.model}',
        'os_version': 'Android ${info.version.release}',
        'android_sdk': info.version.sdkInt,
        'last_device_update': DateTime.now().toUtc().toIso8601String(),
        ...timezone,
      };
    } else if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return {
        'device_platform': 'ios',
        'device_model': info.utsname.machine,
        'os_version': 'iOS ${info.systemVersion}',
        'last_device_update': DateTime.now().toUtc().toIso8601String(),
        ...timezone,
      };
    }
    return {
      'device_platform': Platform.operatingSystem,
      'last_device_update': DateTime.now().toUtc().toIso8601String(),
      ...timezone,
    };
  }

  /// Returns the device's current timezone info.
  /// This is auto-detected but can be overridden by the user in settings.
  static Map<String, dynamic> _getTimezoneInfo() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60).abs();
    final sign = hours >= 0 ? '+' : '-';
    final utcOffset = 'UTC$sign${hours.abs().toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';

    return {
      'timezone_name': now.timeZoneName,
      'timezone_offset_minutes': offset.inMinutes,
      'timezone_utc_offset': utcOffset,
      'timezone_auto_detected': true,
    };
  }

  /// Returns just the timezone metadata for manual updates.
  static Map<String, dynamic> getTimezoneMetadata({
    String? manualTimezoneName,
    int? manualOffsetMinutes,
  }) {
    if (manualTimezoneName != null && manualOffsetMinutes != null) {
      final hours = manualOffsetMinutes ~/ 60;
      final minutes = manualOffsetMinutes.remainder(60).abs();
      final sign = hours >= 0 ? '+' : '-';
      final utcOffset = 'UTC$sign${hours.abs().toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      return {
        'timezone_name': manualTimezoneName,
        'timezone_offset_minutes': manualOffsetMinutes,
        'timezone_utc_offset': utcOffset,
        'timezone_auto_detected': false,
      };
    }
    return _getTimezoneInfo();
  }
}
