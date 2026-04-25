import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/conversation_model.dart';

class ChatListRemoteDataSource {
  ChatListRemoteDataSource(this._client);
  final SupabaseClient _client;

  /// Postgrest embedding: подтягиваем оба профиля и последнее сообщение.
  static const String _select = '''
    id,
    user1_id,
    user2_id,
    updated_at,
    user1:profiles!conversations_user1_id_fkey(id,username,display_name,avatar_url,is_online,last_seen,created_at),
    user2:profiles!conversations_user2_id_fkey(id,username,display_name,avatar_url,is_online,last_seen,created_at),
    last_message:messages!conversations_last_message_id_fkey(id,conversation_id,sender_id,content,is_read,created_at)
  ''';

  Future<List<ConversationModel>> getConversations(String userId) async {
    final List<dynamic> rows = await _client
        .from('conversations')
        .select(_select)
        .or('user1_id.eq.$userId,user2_id.eq.$userId')
        .order('updated_at', ascending: false);

    final List<ConversationModel> list = rows
        .cast<Map<String, dynamic>>()
        .map(ConversationModel.fromJson)
        .toList(growable: true);

    if (list.isEmpty) return list;

    // Считаем непрочитанные для каждого диалога.
    final List<String> ids = list.map((ConversationModel c) => c.id).toList();
    final List<dynamic> unreadRows = await _client
        .from('messages')
        .select('conversation_id')
        .eq('is_read', false)
        .neq('sender_id', userId)
        .inFilter('conversation_id', ids);

    final Map<String, int> counts = <String, int>{};
    for (final dynamic row in unreadRows) {
      final String cid =
          (row as Map<String, dynamic>)['conversation_id'] as String;
      counts[cid] = (counts[cid] ?? 0) + 1;
    }

    return list
        .map((ConversationModel c) => c.copyWith(unreadCount: counts[c.id] ?? 0))
        .toList();
  }

  Future<ConversationModel> createOrGetConversation(
    String currentUserId,
    String peerId,
  ) async {
    if (currentUserId == peerId) {
      throw const AppException('Нельзя начать диалог с самим собой');
    }
    // Нормализуем порядок: user1_id < user2_id (см. CHECK в миграции).
    final bool firstIsUser1 = currentUserId.compareTo(peerId) < 0;
    final String user1 = firstIsUser1 ? currentUserId : peerId;
    final String user2 = firstIsUser1 ? peerId : currentUserId;

    final List<dynamic> existing = await _client
        .from('conversations')
        .select(_select)
        .eq('user1_id', user1)
        .eq('user2_id', user2)
        .limit(1);
    if (existing.isNotEmpty) {
      return ConversationModel.fromJson(existing.first as Map<String, dynamic>);
    }

    await _client
        .from('conversations')
        .insert(<String, dynamic>{'user1_id': user1, 'user2_id': user2});

    final Map<String, dynamic> created = await _client
        .from('conversations')
        .select(_select)
        .eq('user1_id', user1)
        .eq('user2_id', user2)
        .single();
    return ConversationModel.fromJson(created);
  }

  /// Стрим-тик: любое изменение, касающееся списка чатов, заставляет
  /// UI перезапросить данные.
  Stream<void> watchChanges(String userId) {
    final StreamController<void> controller = StreamController<void>.broadcast();
    final RealtimeChannel channel = _client
        .channel('public:chat_list:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (PostgresChangePayload _) => controller.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (PostgresChangePayload _) => controller.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (PostgresChangePayload _) => controller.add(null),
        );
    channel.subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };

    return controller.stream;
  }
}
