import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Фоновая «жидкое стекло» подложка: мягкие размытые цветовые пятна под
/// контентом. Раньше это был no-op (просто `child`); теперь рисует пару
/// приглушённых радиальных бликов в фирменных цветах, создавая глубину под
/// полупрозрачными карточками и аппбаром. На светлой теме блики едва заметны,
/// в тёмной — дают «ночное свечение».
class LiquidGlassBackground extends StatelessWidget {
  const LiquidGlassBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ColoredBox(color: cs.surface),
        ),
        Positioned(
          top: -120,
          right: -80,
          child: _Blob(
            color: cs.primary.withValues(alpha: dark ? 0.22 : 0.12),
            size: 280,
          ),
        ),
        Positioned(
          bottom: -140,
          left: -100,
          child: _Blob(
            color: cs.secondary.withValues(alpha: dark ? 0.18 : 0.10),
            size: 320,
          ),
        ),
        child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Карточка со стеклянным эффектом. Сохраняет прежний API
/// (`padding`, `margin`, `borderRadius`, `blur`), но теперь при `blur > 0`
/// действительно размывает фон через [BackdropFilter] и рисует
/// полупрозрачную поверхность с тонкой светящейся кромкой. При `blur == 0`
/// ведёт себя как премиальная «сплошная» карточка с мягкой тенью —
/// поведение, совместимое с прежними вызовами.
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
  final double blur;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    final Widget content = Padding(padding: padding, child: child);

    final Border border = Border.all(
      color: dark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.7),
      width: 1,
    );

    if (blur > 0) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: AppShadows.sm(Theme.of(context).brightness),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh
                    .withValues(alpha: dark ? 0.55 : 0.65),
                borderRadius: radius,
                border: border,
              ),
              child: content,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: dark ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
        borderRadius: radius,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: dark ? 0.5 : 0.7),
        ),
        boxShadow: AppShadows.sm(Theme.of(context).brightness),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

/// AppBar со стеклянным эффектом: фон полупрозрачный и размыт через
/// [BackdropFilter], под заголовком — тонкая «hairline» граница вместо жёсткой
/// тени. Контент под аппбаром мягко просвечивает при скролле. API совпадает с
/// прежним (`title`, `leading`, `actions`, `bottom`), поэтому существующие
/// экраны не требуют правок.
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
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: dark ? 0.72 : 0.78),
            border: Border(
              bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                width: 0.6,
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            scrolledUnderElevation: 0,
            elevation: 0,
            title: title,
            leading: leading,
            actions: actions,
            bottom: bottom,
          ),
        ),
      ),
    );
  }
}
