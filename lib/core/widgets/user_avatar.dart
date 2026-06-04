import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Аватар пользователя с корректной обработкой загрузки и ошибок.
///
/// Стандартный `CircleAvatar.backgroundImage` не отображает `child`
/// (инициалы), пока картинка грузится или если запрос упал — пользователь
/// видит пустой цветной круг. Этот виджет всегда показывает инициалы
/// фоном, а сетевая картинка прорисовывается поверх только после успешной
/// загрузки. Если URL `null` или загрузка провалилась — остаются инициалы.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.radius,
    required this.initial,
    this.avatarUrl,
    this.backgroundColor,
    this.foregroundColor,
  });

  final double radius;
  final String initial;
  final String? avatarUrl;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color bg = backgroundColor ?? theme.colorScheme.primaryContainer;
    final Color fg = foregroundColor ?? theme.colorScheme.onPrimaryContainer;
    final double size = radius * 2;
    // Deterministic gradients for beautiful placeholder avatars
    final int code = initial.isNotEmpty ? initial.codeUnitAt(0) : 0;
    final List<Color> gradientColors;
    if (backgroundColor != null) {
      gradientColors = [bg, bg];
    } else {
      final List<List<Color>> palettes = [
        [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
        [const Color(0xFFEC4899), const Color(0xFFD946EF)],
        [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
        [const Color(0xFFF59E0B), const Color(0xFFD97706)],
        [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
        [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)],
        [const Color(0xFF10B981), const Color(0xFF059669)],
      ];
      gradientColors = palettes[code % palettes.length];
    }
    final Color textColor = backgroundColor != null ? fg : Colors.white;

    final Widget fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
        boxShadow: AppShadows.sm(theme.brightness),
      ),
      child: Text(
        initial,
        style: (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
          color: textColor,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          height: 1,
        ),
      ),
    );

    final String? url = avatarUrl;
    if (url == null || url.isEmpty) {
      return fallback;
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (BuildContext _, __) => fallback,
          errorWidget: (BuildContext _, __, ___) => fallback,
          fadeInDuration: AppDurations.fast,
          fadeInCurve: AppCurves.standard,
        ),
      ),
    );
  }
}
