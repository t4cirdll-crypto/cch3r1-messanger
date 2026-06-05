import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/prefs_init.dart';

/// Локальные настройки приложения, которые не лежат в Supabase
/// (тема оформления и пр.).
const String _kThemeModeKey = 'settings.theme_mode';

ThemeMode _parseThemeMode(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'system':
    default:
      return ThemeMode.system;
  }
}

String _serializeThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 'light';
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
  }
}

final FutureProvider<SharedPreferences> sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((Ref _) => getSharedPreferencesSafely());

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    final SharedPreferences prefs =
        await ref.watch(sharedPreferencesProvider.future);
    return _parseThemeMode(prefs.getString(_kThemeModeKey));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(mode);
    final SharedPreferences prefs =
        await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(_kThemeModeKey, _serializeThemeMode(mode));
  }
}

final AsyncNotifierProvider<ThemeModeController, ThemeMode>
    themeModeControllerProvider =
    AsyncNotifierProvider<ThemeModeController, ThemeMode>(
        ThemeModeController.new);
