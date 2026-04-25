import 'package:flutter/material.dart';

/// Пока `authControllerProvider` определяет текущее состояние сессии,
/// пользователь видит минималистичный экран загрузки.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
