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

  static const List<List<Color>> _palettes = <List<Color>>[
    <Color>[Color(0xFF6366F1), Color(0xFF4F46E5)],
    <Color>[Color(0xFFDB6E9A), Color(0xFFB54B7A)],
    <Color>[Color(0xFF45A995), Color(0xFF278473)],
    <Color>[Color(0xFFD29A52), Color(0xFFB17B37)],
    <Color>[Color(0xFF5C93D8), Color(0xFF3F72B4)],
    <Color>[Color(0xFF9B83CD), Color(0xFF795FB0)],
    <Color>[Color(0xFF78A269), Color(0xFF527F43)],
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color bg = backgroundColor ?? theme.colorScheme.primaryContainer;
    final Color fg = foregroundColor ?? theme.colorScheme.onPrimaryContainer;
    final double size = radius * 2;
    final int code = initial.isNotEmpty ? initial.codeUnitAt(0) : 0;
    final List<Color> gradientColors;
    if (backgroundColor != null) {
      gradientColors = [bg, bg];
    } else {
      gradientColors = _palettes[code % _palettes.length];
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
          memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
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
