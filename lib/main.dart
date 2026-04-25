import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'core/services/local_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Запрещаем делать скриншоты/запись экрана приложения (в дополнение к FLAG_SECURE).
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      debug: kDebugMode,
    );
  } catch (error, stackTrace) {
    debugPrint('Supabase init error: $error\n$stackTrace');
    rethrow;
  }

  await LocalNotificationService.init();

  runApp(const ProviderScope(child: CchrMessangerApp()));
}
