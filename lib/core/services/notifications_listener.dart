import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/chat/domain/entities/message_entity.dart';
import '../../features/chat_list/domain/entities/conversation_entity.dart';
import '../../features/chat_list/presentation/providers/chat_list_providers.dart';
import '../providers/supabase_providers.dart';
import 'local_notification_service.dart';

/// Идентификатор диалога, который сейчас открыт у юзера.
/// Если совпадает с conversation_id входящего сообщения — уведомление не
/// показываем (как в Telegram при открытом чате).
final StateProvider<String?> activeConversationIdProvider =
    StateProvider<String?>((Ref ref) => null);

/// Фоновый слушатель INSERT-ов в `messages`. Опирается на RLS для фильтрации:
/// realtime присылает только те сообщения, к которым у юзера есть SELECT-доступ.
final Provider<MessageNotificationsListener> messageNotificationsListenerProvider =
    Provider<MessageNotificationsListener>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  final MessageNotificationsListener listener =
      MessageNotificationsListener(client: client, ref: ref);
  ref.onDispose(listener.dispose);
  return listener;
});

class MessageNotificationsListener {
  MessageNotificationsListener({
    required SupabaseClient client,
    required Ref ref,
  })  : _client = client,
        _ref = ref;

  final SupabaseClient _client;
  final Ref _ref;
  RealtimeChannel? _channel;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _channel = _client
        .channel('public:messages:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: _onInsert,
        )
        .subscribe();
  }

  void _onInsert(PostgresChangePayload payload) {
    final Map<String, dynamic> row = payload.newRecord;
    final String? convId = row['conversation_id'] as String?;
    final String? senderId = row['sender_id'] as String?;
    if (convId == null || senderId == null) return;

    final String? myId = _client.auth.currentUser?.id;
    if (myId == null || myId == senderId) return;

    final String? activeId = _ref.read(activeConversationIdProvider);
    if (activeId == convId) return;

    final List<ConversationEntity> convs =
        _ref.read(chatListControllerProvider).valueOrNull ??
            const <ConversationEntity>[];
    ConversationEntity? conv;
    for (final ConversationEntity c in convs) {
      if (c.id == convId) {
        conv = c;
        break;
      }
    }
    if (conv != null && conv.muted) return;

    final String title = conv?.effectiveTitle ?? 'Новое сообщение';
    final String body = _previewBody(row);

    LocalNotificationService.showMessage(
      id: convId.hashCode,
      title: title,
      body: body,
    );
  }

  static String _previewBody(Map<String, dynamic> row) {
    final String? content = row['content'] as String?;
    if (content != null && content.trim().isNotEmpty) return content.trim();
    final AttachmentKind? kind =
        AttachmentKind.fromString(row['attachment_kind'] as String?);
    switch (kind) {
      case AttachmentKind.image:
        return '📷 Фото';
      case AttachmentKind.video:
        return '🎥 Видео';
      case AttachmentKind.voice:
        return '🎤 Голосовое сообщение';
      case AttachmentKind.file:
        final String? name = row['attachment_name'] as String?;
        return '📎 ${name ?? 'Файл'}';
      case AttachmentKind.gif:
        return '🎞 GIF';
      case null:
        return 'Новое сообщение';
    }
  }

  Future<void> dispose() async {
    final RealtimeChannel? c = _channel;
    if (c != null) await _client.removeChannel(c);
    _channel = null;
    _started = false;
  }
}
