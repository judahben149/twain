import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceInfoService {
  static final _deviceInfo = DeviceInfoPlugin();

  static Future<Map<String, dynamic>> getDeviceMetadata() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return {
        'device_platform': 'android',
        'device_model': '${info.manufacturer} ${info.model}',
        'os_version': 'Android ${info.version.release}',
        'last_device_update': DateTime.now().toUtc().toIso8601String(),
      };
    } else if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return {
        'device_platform': 'ios',
        'device_model': info.utsname.machine,
        'os_version': 'iOS ${info.systemVersion}',
        'last_device_update': DateTime.now().toUtc().toIso8601String(),
      };
    }
    return {
      'device_platform': Platform.operatingSystem,
      'last_device_update': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
