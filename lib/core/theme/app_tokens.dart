import 'package:flutter/material.dart';

/// Единые дизайн-токены приложения: отступы, радиусы, длительности, кривые,
/// эластичные тени и фирменные градиенты. Любой premium-полировке UI следует
/// тянуть значения отсюда, а не хардкодить их по месту — так визуальный ритм
/// остаётся согласованным во всех экранах.
///
/// Шкала отступов кратна 4 — стандарт Material. Радиусы выстроены так, чтобы
/// вложенные элементы (поле внутри карточки) визуально «сидели» один в другом
/// без оптического зазора.
class AppSpacing {
  const AppSpacing._();

  /// 2 — микрозазор между плотно прижатыми элементами (иконка + цифра).
  static const double xxs = 2;

  /// 4 — базовый шаг сетки.
  static const double xs = 4;

  /// 8 — типовой зазор внутри строки.
  static const double sm = 8;

  /// 12 — зазор между связанными блоками.
  static const double md = 12;

  /// 16 — стандартный внешний/внутренний отступ контента.
  static const double lg = 16;

  /// 20 — крупный внутренний отступ карточек.
  static const double xl = 20;

  /// 24 — отступ секций, диалогов, экранов с формой.
  static const double xxl = 24;

  /// 32 — разрежение между смысловыми секциями.
  static const double xxxl = 32;
}

/// Радиусы скругления. Подобраны так, чтобы поле (16) внутри карточки (20)
/// внутри листа (28) образовывали аккуратную «матрёшку».
class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;

  /// Для бейджей и «таблеток» — гарантированно полукруглые торцы.
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
}

/// Длительности анимаций. Держим их короткими — мессенджер должен ощущаться
/// «мгновенным», но не дёрганым.
class AppDurations {
  const AppDurations._();

  /// 120мс — мгновенная обратная связь (нажатие, цвет).
  static const Duration instant = Duration(milliseconds: 120);

  /// 180мс — появление/исчезновение мелких элементов (бейджи, иконки).
  static const Duration fast = Duration(milliseconds: 180);

  /// 240мс — стандартный переход (слайды, скейлы).
  static const Duration normal = Duration(milliseconds: 240);

  /// 320мс — заметный переход (скролл к низу, появление панелей).
  static const Duration slow = Duration(milliseconds: 320);
}

/// Кривые движения. `emphasized` — фирменная Material 3 кривая для «выразительных»
/// переходов; `standard` — для повседневных.
class AppCurves {
  const AppCurves._();

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve spring = Curves.easeOutBack;
}

/// Эластичные многослойные тени. Premium-вид даёт не одна жёсткая тень, а
/// пара слоёв: близкая «контактная» + дальняя мягкая. Значения зависят от
/// яркости темы — в тёмной теме тени глубже и насыщеннее.
class AppShadows {
  const AppShadows._();

  /// Тонкая тень для приподнятых поверхностей (карточки, плитки).
  static List<BoxShadow> sm(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.28 : 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.18 : 0.03),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];
  }

  /// Средняя тень для плавающих элементов (FAB, всплывающие панели).
  static List<BoxShadow> md(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.38 : 0.08),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.22 : 0.04),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Цветная «свечная» тень под акцентными элементами (отправка, бейдж непрочитанного).
  static List<BoxShadow> glow(Color color, {double opacity = 0.35}) {
    return <BoxShadow>[
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];
  }
}
