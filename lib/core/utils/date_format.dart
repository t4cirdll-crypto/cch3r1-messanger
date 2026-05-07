import 'package:intl/intl.dart';

/// Форматирование дат для UI.
///
/// Все методы устойчивы к перекосу системных часов: если у пользователя
/// неверно установлены дата/время и серверный timestamp оказывается
/// «в будущем» относительно `DateTime.now()`, мы трактуем такое значение
/// как «только что / сегодня», а не показываем заведомо мусорные строки
/// типа «понедельник» для свежего сообщения или «−10 мин. назад».
class DateFormatter {
  const DateFormatter._();

  static String shortTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  static String conversationTimestamp(DateTime dt) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime d = DateTime(dt.year, dt.month, dt.day);

    final int dayDiff = today.difference(d).inDays;

    // dt в будущем относительно локальных часов (часы устройства отстают).
    // Воспринимаем как «сегодня» и показываем время.
    if (dayDiff <= 0 || d == today) {
      return DateFormat('HH:mm').format(dt);
    }
    if (dayDiff == 1) {
      return 'вчера';
    }
    if (dayDiff < 7) {
      return DateFormat.E('ru').format(dt);
    }
    return DateFormat('dd.MM.yy').format(dt);
  }

  static String lastSeenAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    // Отрицательная разница ⇒ часы устройства отстают и серверный
    // timestamp выглядит «в будущем». Не показываем «−5 мин. назад».
    if (diff.isNegative || diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return DateFormat('dd.MM.yy').format(dt);
  }
}
