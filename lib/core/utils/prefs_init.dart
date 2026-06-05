import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Безопасный `SharedPreferences.getInstance()`.
///
/// На iOS известен баг: `shared_preferences` 2.3.x при холодном старте
/// иногда бросает `PlatformException(channel-error, LegacyUserDefaultsApi.getAll)`,
/// потому что Pigeon-канал регистрируется позже первого вызова. Без retry
/// это валит всё приложение в `_BootErrorApp` ещё до `runApp`.
///
/// Пытаемся получить инстанс 3 раза с нарастающей задержкой; если и после
/// этого канал не ответил — пробрасываем ошибку дальше, чтобы зона её
/// поймала и положила в `_BootErrorApp` (там будет stacktrace, по нему
/// видно, что уже не prefs).
Future<SharedPreferences> getSharedPreferencesSafely() async {
  const List<int> delays = <int>[0, 50, 150];
  Object? lastError;
  for (int i = 0; i < delays.length; i++) {
    if (delays[i] > 0) {
      await Future<void>.delayed(Duration(milliseconds: delays[i]));
    }
    try {
      return await SharedPreferences.getInstance();
    } on PlatformException catch (e) {
      lastError = e;
    }
  }
  throw lastError ?? StateError('SharedPreferences.getInstance failed');
}
