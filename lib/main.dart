import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/supabase_config.dart';
import 'core/services/local_notification_service.dart';

Future<void> main() async {
  // Любая необработанная ошибка инициализации не должна оставлять
  // экран белым — показываем диагностику прямо в приложении.
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

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
      runApp(_BootErrorApp(
        title: 'Supabase init error',
        error: error,
        stackTrace: stackTrace,
      ));
      return;
    }

    try {
      await LocalNotificationService.init();
    } catch (error, stackTrace) {
      // Уведомления — не критичны, продолжаем без них.
      debugPrint('LocalNotificationService init error: $error\n$stackTrace');
    }

    runApp(const ProviderScope(child: CchrMessangerApp()));
  }, (Object error, StackTrace stackTrace) {
    debugPrint('Uncaught zone error: $error\n$stackTrace');
    runApp(_BootErrorApp(
      title: 'Boot error',
      error: error,
      stackTrace: stackTrace,
    ));
  });
}

class _BootErrorApp extends StatelessWidget {
  const _BootErrorApp({
    required this.title,
    required this.error,
    required this.stackTrace,
  });

  final String title;
  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            '$error\n\n$stackTrace',
            style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
          ),
        ),
      ),
    );
  }
}
