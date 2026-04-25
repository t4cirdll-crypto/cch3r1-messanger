import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_model.dart';
import '../models/reaction_model.dart';

class ChatRemoteDataSource {
  ChatRemoteDataSource(this._client);
  final SupabaseClient _client;

  static const String attachmentsBucket = 'chat-attachments';

  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 30,
    DateTime? before,
  }) async {
    dynamic query = _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final List<dynamic> rows = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .cast<Map<String, dynamic>>()
        .map(MessageModel.fromJson)
        .toList();
  }

  Future<List<ReactionModel>> getReactionsForMessages(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return <ReactionModel>[];
    final List<dynamic> rows = await _client
        .from('message_reactions')
        .select()
        .inFilter('message_id', messageIds);
    return rows
        .cast<Map<String, dynamic>>()
        .map(ReactionModel.fromJson)
        .toList();
  }

  Future<List<MessageModel>> getMessagesByIds(List<String> ids) async {
    if (ids.isEmpty) return <MessageModel>[];
    final List<dynamic> rows =
        await _client.from('messages').select().inFilter('id', ids);
    return rows
        .cast<Map<String, dynamic>>()
        .map(MessageModel.fromJson)
        .toList();
  }

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    String? content,
    AttachmentUpload? attachment,
    String? replyToId,
    String? forwardedFromMessageId,
    String? forwardedFromSenderId,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': senderId,
      if ((content ?? '').trim().isNotEmpty) 'content': content!.trim(),
      if (replyToId != null) 'reply_to_id': replyToId,
      if (forwardedFromMessageId != null)
        'forwarded_from_message_id': forwardedFromMessageId,
      if (forwardedFromSenderId != null)
        'forwarded_from_sender_id': forwardedFromSenderId,
      if (attachment != null) ...<String, dynamic>{
        'attachment_path': attachment.path,
        'attachment_kind': attachment.kind,
        if (attachment.name != null) 'attachment_name': attachment.name,
        if (attachment.mime != null) 'attachment_mime': attachment.mime,
        if (attachment.size != null) 'attachment_size': attachment.size,
        if (attachment.durationMs != null)
          'attachment_duration_ms': attachment.durationMs,
        if (attachment.width != null) 'attachment_width': attachment.width,
        if (attachment.height != null) 'attachment_height': attachment.height,
      },
    };

    final Map<String, dynamic> inserted =
        await _client.from('messages').insert(payload).select().single();
    return MessageModel.fromJson(inserted);
  }

  /// Загружает файл во вложение чата.
  Future<String> uploadAttachment({
    required String conversationId,
    required String messageId,
    required String extension,
    required String mime,
    Uint8List? bytes,
    File? file,
  }) async {
    assert(bytes != null || file != null,
        'Нужно передать bytes или file для загрузки');
    final String key =
        '$conversationId/$messageId${extension.startsWith('.') ? extension : '.$extension'}';
    final FileOptions options = FileOptions(
      contentType: mime,
      upsert: true,
    );
    if (bytes != null) {
      await _client.storage.from(attachmentsBucket).uploadBinary(
            key,
            bytes,
            fileOptions: options,
          );
    } else {
      await _client.storage.from(attachmentsBucket).upload(
            key,
            file!,
            fileOptions: options,
          );
    }
    return key;
  }

  Future<String> createSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) {
    return _client.storage
        .from(attachmentsBucket)
        .createSignedUrl(storagePath, expiresInSeconds);
  }

  Future<void> markAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    // 1) Двусторонний DM: обновляем is_read у входящих сообщений (для
    //    обратной совместимости — UI всё ещё ориентируется на этот флаг).
    await _client
        .from('messages')
        .update(<String, dynamic>{'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', currentUserId)
        .eq('is_read', false);
    // 2) Универсальный last_read_at в `conversation_members` (для групп).
    await _client.rpc<void>(
      'fn_mark_conv_read',
      params: <String, dynamic>{'p_conv_id': conversationId},
    );
  }

  Future<void> editMessage({
    required String messageId,
    required String content,
  }) async {
    await _client.rpc<void>(
      'fn_message_edit',
      params: <String, dynamic>{
        'p_message_id': messageId,
        'p_content': content,
      },
    );
  }

  Future<void> deleteForAll(String messageId) async {
    await _client.rpc<void>(
      'fn_message_delete_for_all',
      params: <String, dynamic>{'p_message_id': messageId},
    );
  }

  Future<void> setPin({
    required String messageId,
    required bool pinned,
  }) async {
    await _client.rpc<void>(
      'fn_message_set_pin',
      params: <String, dynamic>{
        'p_message_id': messageId,
        'p_pinned': pinned,
      },
    );
  }

  Future<void> addReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _client.from('message_reactions').upsert(<String, dynamic>{
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    });
  }

  Future<void> removeReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _client
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .eq('emoji', emoji);
  }

  Future<List<MessageModel>> searchInConversation({
    required String conversationId,
    required String query,
    int limit = 100,
  }) async {
    final String pattern = '%${query.replaceAll('%', '\\%')}%';
    final List<dynamic> rows = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .isFilter('deleted_at', null)
        .ilike('content', pattern)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .cast<Map<String, dynamic>>()
        .map(MessageModel.fromJson)
        .toList();
  }

  Future<List<MessageModel>> getPinnedMessages(String conversationId) async {
    final List<dynamic> rows = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .not('pinned_at', 'is', null)
        .isFilter('deleted_at', null)
        .order('pinned_at', ascending: false);
    return rows
        .cast<Map<String, dynamic>>()
        .map(MessageModel.fromJson)
        .toList();
  }

  /// Подписка на INSERT/UPDATE в `messages` конкретного диалога.
  Stream<MessageModel> watchMessages(String conversationId) {
    final StreamController<MessageModel> controller =
        StreamController<MessageModel>.broadcast();

    final RealtimeChannel channel = _client
        .channel('public:messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (PostgresChangePayload payload) {
            controller.add(MessageModel.fromJson(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (PostgresChangePayload payload) {
            controller.add(MessageModel.fromJson(payload.newRecord));
          },
        );
    channel.subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };

    return controller.stream;
  }

  /// Подписка на изменения реакций (любые сообщения, фильтр по диалогу
  /// делается клиентом).
  Stream<ReactionEvent> watchReactions() {
    final StreamController<ReactionEvent> controller =
        StreamController<ReactionEvent>.broadcast();

    final RealtimeChannel channel = _client
        .channel('public:message_reactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'message_reactions',
          callback: (PostgresChangePayload payload) {
            controller.add(ReactionEvent(
              type: ReactionEventType.added,
              reaction: ReactionModel.fromJson(payload.newRecord),
            ));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'message_reactions',
          callback: (PostgresChangePayload payload) {
            controller.add(ReactionEvent(
              type: ReactionEventType.removed,
              reaction: ReactionModel.fromJson(payload.oldRecord),
            ));
          },
        );
    channel.subscribe();
    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }
}

/// Параметры вложения, отправляемые вместе с `sendMessage` после загрузки.
class AttachmentUpload {
  const AttachmentUpload({
    required this.path,
    required this.kind,
    this.name,
    this.mime,
    this.size,
    this.durationMs,
    this.width,
    this.height,
  });

  final String path;
  final String kind;
  final String? name;
  final String? mime;
  final int? size;
  final int? durationMs;
  final int? width;
  final int? height;
}

enum ReactionEventType { added, removed }

class ReactionEvent {
  const ReactionEvent({required this.type, required this.reaction});
  final ReactionEventType type;
  final ReactionModel reaction;
}
