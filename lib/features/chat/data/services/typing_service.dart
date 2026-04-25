import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Тонкая обёртка над Supabase Realtime broadcast-каналом для одного
/// диалога. Принимает события `typing` от других участников и шлёт
/// собственные с throttle. Не требует записи в БД.
class TypingChannel {
  TypingChannel({
    required SupabaseClient client,
    required String conversationId,
    required String selfUserId,
  })  : _client = client,
        _conversationId = conversationId,
        _selfUserId = selfUserId;

  final SupabaseClient _client;
  final String _conversationId;
  final String _selfUserId;

  /// Сколько времени мы считаем юзера «печатающим» после последнего ping.
  static const Duration _activeFor = Duration(seconds: 4);

  /// Минимальный интервал между отправками собственного `typing`.
  static const Duration _throttle = Duration(seconds: 2);

  RealtimeChannel? _channel;
  bool _subscribed = false;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  final Map<String, Timer> _timers = <String, Timer>{};
  final Set<String> _active = <String>{};

  final StreamController<Set<String>> _controller =
      StreamController<Set<String>>.broadcast();

  /// Поток множества userId, которые сейчас «печатают».
  Stream<Set<String>> get typingUsers => _controller.stream;

  /// Подписаться на канал. Безопасно вызывать многократно.
  void connect() {
    if (_channel != null) return;
    final RealtimeChannel ch = _client.channel(
      'typing:$_conversationId',
      opts: const RealtimeChannelConfig(ack: false, self: false),
    );
    ch.onBroadcast(event: 'typing', callback: _onBroadcast);
    ch.subscribe((RealtimeSubscribeStatus status, Object? _) {
      _subscribed = status == RealtimeSubscribeStatus.subscribed;
    });
    _channel = ch;
  }

  void _onBroadcast(Map<String, dynamic> payload) {
    final Object? rawUid = payload['user_id'];
    if (rawUid is! String) return;
    if (rawUid == _selfUserId) return;
    _timers[rawUid]?.cancel();
    _active.add(rawUid);
    _emit();
    _timers[rawUid] = Timer(_activeFor, () {
      _active.remove(rawUid);
      _timers.remove(rawUid);
      _emit();
    });
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(Set<String>.unmodifiable(_active));
  }

  /// Отправить ping «я печатаю». Вызывать на каждый keystroke —
  /// внутри уже есть throttle.
  Future<void> ping() async {
    final DateTime now = DateTime.now();
    if (now.difference(_lastSent) < _throttle) return;
    final RealtimeChannel? ch = _channel;
    if (ch == null || !_subscribed) return;
    _lastSent = now;
    try {
      await ch.sendBroadcastMessage(
        event: 'typing',
        payload: <String, dynamic>{'user_id': _selfUserId},
      );
    } catch (_) {
      // Сетевые ошибки в realtime игнорируем — это не критично.
    }
  }

  Future<void> dispose() async {
    for (final Timer t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _active.clear();
    if (!_controller.isClosed) {
      await _controller.close();
    }
    final RealtimeChannel? ch = _channel;
    _channel = null;
    if (ch != null) {
      await _client.removeChannel(ch);
    }
  }
}
