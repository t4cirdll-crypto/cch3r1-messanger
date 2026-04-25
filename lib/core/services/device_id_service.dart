import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Получает стабильный идентификатор устройства, к которому привязана админка.
///
/// Android: ANDROID_ID — стабилен в пределах подписи приложения и
/// аккаунта пользователя на устройстве. После переустановки/смены подписи
/// меняется. Для нашего сценария «привязка админки к телефону KillDev» этого
/// достаточно.
class DeviceIdService {
  DeviceIdService._();

  static String? _cached;

  static Future<String> get() async {
    final String? c = _cached;
    if (c != null) return c;
    final DeviceInfoPlugin plugin = DeviceInfoPlugin();
    String value;
    if (Platform.isAndroid) {
      final AndroidDeviceInfo info = await plugin.androidInfo;
      value = info.id;
    } else if (Platform.isIOS) {
      final IosDeviceInfo info = await plugin.iosInfo;
      value = info.identifierForVendor ?? 'unknown-ios';
    } else if (Platform.isLinux) {
      final LinuxDeviceInfo info = await plugin.linuxInfo;
      value = info.machineId ?? 'unknown-linux';
    } else if (Platform.isMacOS) {
      final MacOsDeviceInfo info = await plugin.macOsInfo;
      value = info.systemGUID ?? 'unknown-macos';
    } else if (Platform.isWindows) {
      final WindowsDeviceInfo info = await plugin.windowsInfo;
      value = info.deviceId;
    } else {
      value = 'unknown-platform';
    }
    _cached = value;
    return value;
  }
}
