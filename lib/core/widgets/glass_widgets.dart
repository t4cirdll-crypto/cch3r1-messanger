import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Фоновая «жидкое стекло» подложка: лёгкий диагональный градиент плюс
/// несколько мягко размытых цветовых пятен в фирменных тонах. Создаёт глубину
/// и «свечение», сквозь которое просвечивают полупрозрачные стеклянные
/// поверхности (карточки, аппбары, пузыри). Подложка непрозрачна снизу, поэтому
/// её безопасно ставить под прозрачный `Scaffold`.
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? <Color>[
                        cs.surface,
                        Color.alphaBlend(
                          cs.primary.withValues(alpha: 0.07),
                          cs.surface,
                        ),
                        cs.surfaceContainerLowest,
                      ]
                    : <Color>[
                        cs.surface,
                        Color.alphaBlend(
                          cs.primary.withValues(alpha: 0.04),
                          cs.surface,
                        ),
                        cs.surfaceContainerLow,
                      ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -130,
          right: -90,
          child: _Blob(
            color: cs.primary.withValues(alpha: dark ? 0.30 : 0.16),
            size: 300,
          ),
        ),
        Positioned(
          top: 180,
          left: -120,
          child: _Blob(
            color: cs.tertiary.withValues(alpha: dark ? 0.22 : 0.12),
            size: 260,
          ),
        ),
        Positioned(
          bottom: -160,
          left: -90,
          child: _Blob(
            color: cs.secondary.withValues(alpha: dark ? 0.26 : 0.13),
            size: 340,
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
        imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
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

/// Базовая «жидкое стекло» поверхность — переиспользуемый frosted-слой.
///
/// Слои сверху вниз: мягкая тень → размытие фона ([BackdropFilter]) →
/// полупрозрачная морозная заливка → диагональный световой блик → светящаяся
/// кромка по контуру. Используется и карточкой, и аппбаром, и композером —
/// чтобы стекло везде выглядело одинаково.
class LiquidGlassPanel extends StatelessWidget {
  const LiquidGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppRadius.lg,
    this.blur = 18,
    this.tintOpacity,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;

  /// Прозрачность морозной заливки. Если `null` — подбирается по теме.
  final double? tintOpacity;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Brightness brightness = Theme.of(context).brightness;
    final bool dark = brightness == Brightness.dark;
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final double fill = tintOpacity ?? (dark ? 0.34 : 0.46);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow ? AppShadows.md(brightness) : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            // Морозная полупрозрачная заливка поверх размытия.
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: fill),
              borderRadius: radius,
            ),
            child: DecoratedBox(
              // Диагональный блик + светящаяся кромка.
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? <Color>[
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.02),
                        ]
                      : <Color>[
                          Colors.white.withValues(alpha: 0.45),
                          Colors.white.withValues(alpha: 0.12),
                        ],
                ),
                border: Border.all(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: padding == null
                  ? child
                  : Padding(padding: padding!, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Карточка со стеклянным эффектом. Сохраняет прежний API
/// (`padding`, `margin`, `borderRadius`, `blur`), но теперь всегда рисует
/// настоящее «жидкое стекло» поверх [LiquidGlassPanel]: размытие фона,
/// морозную полупрозрачную заливку и светящуюся кромку. `blur == 0`
/// (значение по умолчанию у старых вызовов) трактуется как стандартное
/// размытие, чтобы существующие экраны сразу получили стеклянный вид.
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
    return LiquidGlassPanel(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      blur: blur > 0 ? blur : 16,
      child: child,
    );
  }
}

/// AppBar со стеклянным эффектом: фон полупрозрачный и размыт через
/// [BackdropFilter], сверху — лёгкий световой блик, под заголовком тонкая
/// «hairline» граница вместо жёсткой тени. Контент под аппбаром мягко
/// просвечивает при скролле. API совпадает с прежним (`title`, `leading`,
/// `actions`, `bottom`), поэтому существующие экраны не требуют правок.
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
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color.alphaBlend(
                  Colors.white.withValues(alpha: dark ? 0.08 : 0.30),
                  cs.surface.withValues(alpha: dark ? 0.72 : 0.78),
                ),
                cs.surface.withValues(alpha: dark ? 0.72 : 0.80),
              ],
            ),
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
