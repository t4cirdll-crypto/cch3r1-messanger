import 'package:intl/intl.dart';

/// Форматирование дат для UI.
class DateFormatter {
  const DateFormatter._();

  static String shortTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  static String conversationTimestamp(DateTime dt) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime d = DateTime(dt.year, dt.month, dt.day);

    if (d == today) {
      return DateFormat('HH:mm').format(dt);
    }
    if (today.difference(d).inDays == 1) {
      return 'вчера';
    }
    if (today.difference(d).inDays < 7) {
      return DateFormat.E('ru').format(dt);
    }
    return DateFormat('dd.MM.yy').format(dt);
  }

  static String lastSeenAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return DateFormat('dd.MM.yy').format(dt);
  }
}
