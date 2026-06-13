import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Тональная поверхность Material You — переиспользуемый «контейнер» уровня
/// `surfaceContainerHigh` со скруглением, тонкой кромкой `outlineVariant` и
/// (опционально) мягкой тенью. Никаких размытий и градиентов — плоский M3-слой,
/// который одинаково используют карточки на всех экранах.
class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Brightness brightness = Theme.of(context).brightness;
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: radius,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: shadow ? AppShadows.sm(brightness) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// Карточка Material You. Сохраняет прежний API (`padding`, `margin`,
/// `borderRadius`, `blur`) ради совместимости вызовов, но всегда рисует
/// плоскую тональную поверхность поверх [LiquidGlassPanel]. Параметр `blur`
/// больше не влияет на отрисовку.
class GlassmorphicCard extends StatelessWidget {
  const GlassmorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.blur = 0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  /// Не используется (оставлен ради обратной совместимости вызовов).
  final double blur;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassPanel(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      child: child,
    );
  }
}

/// AppBar в стиле Material You. Фон — тональная поверхность темы, при скролле
/// контента под ним появляется мягкий tonal-overlay (`scrolledUnderElevation`).
/// API совпадает с прежним (`title`, `leading`, `actions`, `bottom`), поэтому
/// существующие экраны не требуют правок.
class GlassmorphicAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const GlassmorphicAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.bottom,
  });

  final Widget title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize {
    final double bottomHeight = bottom?.preferredSize.height ?? 0.0;
    return Size.fromHeight(kToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      bottom: bottom,
    );
  }
}
