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

  static String shortTime(DateTime dt) =>
      DateFormat('HH:mm').format(dt.toLocal());

  static String conversationTimestamp(DateTime dt) {
    final DateTime local = dt.toLocal();
    final int dayDiff = _dayDiff(local);

    // dt в будущем относительно локальных часов (часы устройства отстают).
    // Воспринимаем как «сегодня» и показываем время.
    if (dayDiff <= 0) {
      return DateFormat('HH:mm').format(local);
    }
    if (dayDiff == 1) {
      return 'вчера';
    }
    if (dayDiff < 7) {
      return DateFormat.E('ru').format(local);
    }
    return DateFormat('dd.MM.yy').format(local);
  }

  static String messageDayHeader(DateTime dt) {
    final DateTime local = dt.toLocal();
    final int dayDiff = _dayDiff(local);
    if (dayDiff <= 0) return 'сегодня';
    if (dayDiff == 1) return 'вчера';
    if (dayDiff < 7) return DateFormat.EEEE('ru').format(local);
    return DateFormat('dd.MM.yy').format(local);
  }

  static String lastSeenAgo(DateTime dt) {
    final DateTime local = dt.toLocal();
    final Duration diff = DateTime.now().difference(local);
    // Отрицательная разница ⇒ часы устройства отстают и серверный
    // timestamp выглядит «в будущем». Не показываем «−5 мин. назад».
    if (diff.isNegative || diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return DateFormat('dd.MM.yy').format(local);
  }

  static int _dayDiff(DateTime local) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime date = DateTime(local.year, local.month, local.day);
    return today.difference(date).inDays;
  }
}
