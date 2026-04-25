import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_model.dart';

class ChatRemoteDataSource {
  ChatRemoteDataSource(this._client);
  final SupabaseClient _client;

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

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    final Map<String, dynamic> inserted = await _client
        .from('messages')
        .insert(<String, dynamic>{
          'conversation_id': conversationId,
          'sender_id': senderId,
          'content': content,
        })
        .select()
        .single();
    return MessageModel.fromJson(inserted);
  }

  Future<void> markAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    await _client
        .from('messages')
        .update(<String, dynamic>{'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', currentUserId)
        .eq('is_read', false);
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
}
