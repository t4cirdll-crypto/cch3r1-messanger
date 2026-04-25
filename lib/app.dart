import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/routes.dart';
import 'config/theme.dart';
import 'core/constants/app_strings.dart';

class CchrMessangerApp extends ConsumerWidget {
  const CchrMessangerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? light, ColorScheme? dark) {
        return MaterialApp.router(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: AppTheme.light(light),
          darkTheme: AppTheme.dark(dark),
          routerConfig: router,
        );
      },
    );
  }
}
