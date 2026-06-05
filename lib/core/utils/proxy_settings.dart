import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_init.dart';

class ProxySettings {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await getSharedPreferencesSafely();
  }

  static bool get isEnabled => _prefs?.getBool('proxy.enabled') ?? false;
  static set isEnabled(bool value) => _prefs?.setBool('proxy.enabled', value);

  static String get type => _prefs?.getString('proxy.type') ?? 'HTTP';
  static set type(String value) => _prefs?.setString('proxy.type', value);

  static String get host => _prefs?.getString('proxy.host') ?? '';
  static set host(String value) => _prefs?.setString('proxy.host', value);

  static int get port => _prefs?.getInt('proxy.port') ?? 0;
  static set port(int value) => _prefs?.setInt('proxy.port', value);
}
