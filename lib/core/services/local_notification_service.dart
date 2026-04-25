import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Сервис локальных push-уведомлений (без FCM).
/// Работает, пока приложение в foreground / свёрнуто (короткое время).
/// При полностью закрытом приложении не сработает — для этого нужен FCM.
class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationChannel _messageChannel =
      AndroidNotificationChannel(
    'messages',
    'Сообщения',
    description: 'Новые сообщения в чатах',
    importance: Importance.high,
  );

  static Future<void> init() async {
    if (_initialized) return;
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings =
        InitializationSettings(android: android);
    await _plugin.initialize(settings);

    if (defaultTargetPlatform == TargetPlatform.android) {
      final AndroidFlutterLocalNotificationsPlugin? androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(_messageChannel);
      await androidImpl?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  static Future<void> showMessage({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await init();
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _messageChannel.id,
        _messageChannel.name,
        channelDescription: _messageChannel.description,
        priority: Priority.high,
        importance: Importance.high,
        ticker: title,
      ),
    );
    await _plugin.show(id, title, body, details);
  }
}
