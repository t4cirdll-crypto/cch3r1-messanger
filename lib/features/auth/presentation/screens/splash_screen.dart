import 'package:flutter/material.dart';

import 'package:cch3r1_messanger/core/theme/app_tokens.dart';

/// Пока `authControllerProvider` определяет текущее состояние сессии,
/// пользователь видит минималистичный экран загрузки.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder<double>(
          duration: AppDurations.slow,
          curve: AppCurves.spring,
          tween: Tween<double>(begin: 0.92, end: 1),
          builder: (BuildContext context, double scale, Widget? child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Брендовая «печать»: тональная поверхность Material You.
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: AppRadius.xxlAll,
                ),
                child: Icon(
                  Icons.bubble_chart_rounded,
                  size: 44,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
