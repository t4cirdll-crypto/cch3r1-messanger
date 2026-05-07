import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

    final Widget fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(
          color: fg,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w600,
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
          fadeInDuration: const Duration(milliseconds: 150),
        ),
      ),
    );
  }
}
