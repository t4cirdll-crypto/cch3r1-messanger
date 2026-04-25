import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../auth/data/models/profile_model.dart';
import '../../../chat/data/models/message_model.dart';
import '../models/conversation_model.dart';

/// Низкоуровневый источник данных для списка диалогов.
/// Группы / Saved / DM поддерживаются единообразно через
/// `conversation_members` (см. миграцию 0004).
class ChatListRemoteDataSource {
  ChatListRemoteDataSource(this._client);
  final SupabaseClient _client;

  /// SELECT для конверсаций (без peer/members — те загружаются отдельно).
  static const String _convSelect = '''
    id,
    kind,
    title,
    avatar_path,
    created_by,
    updated_at,
    user1_id,
    user2_id,
    self_destruct_seconds,
    last_message:messages!conversations_last_message_id_fkey(id,conversation_id,sender_id,content,is_read,created_at,edited_at,deleted_at,reply_to_id,forwarded_from_message_id,forwarded_from_sender_id,pinned_at,attachment_path,attachment_kind,attachment_name,attachment_mime,attachment_size,attachment_duration_ms,attachment_width,attachment_height,expires_at)
  ''';

  /// Возвращает идентификаторы диалогов, в которых пользователь — участник.
  Future<List<String>> getConversationIds(String userId) async {
    final List<dynamic> rows = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', userId);
    return rows
        .cast<Map<String, dynamic>>()
        .map((Map<String, dynamic> r) => r['conversation_id'] as String)
        .toList(growable: false);
  }

  /// Возвращает «сырой» список диалогов вместе с last_message.
  Future<List<ConversationModel>> getConversationsByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const <ConversationModel>[];
    final List<dynamic> rows = await _client
        .from('conversations')
        .select(_convSelect)
        .inFilter('id', ids)
        .order('updated_at', ascending: false);
    return rows
        .cast<Map<String, dynamic>>()
        .map(ConversationModel.fromJson)
        .toList(growable: false);
  }

  /// Получает все строки conversation_members для перечисленных диалогов
  /// с присоединённым профилем.
  Future<List<ConversationMemberModel>> getMembersForConversations(
    List<String> conversationIds,
  ) async {
    if (conversationIds.isEmpty) return const <ConversationMemberModel>[];
    final List<dynamic> rows = await _client
        .from('conversation_members')
        .select(
          'conversation_id,user_id,role,joined_at,last_read_at,muted_until,'
          'profile:profiles!conversation_members_user_id_fkey(id,username,display_name,bio,avatar_url,is_online,last_seen,created_at)',
        )
        .inFilter('conversation_id', conversationIds);
    return rows
        .cast<Map<String, dynamic>>()
        .map(ConversationMemberModel.fromJson)
        .toList(growable: false);
  }

  /// Считает непрочитанные для каждого диалога: сообщения, у которых
  /// `created_at > last_read_at` и `sender_id != currentUserId`.
  Future<Map<String, int>> getUnreadCounts({
    required String currentUserId,
    required Map<String, DateTime?> lastReadByConversation,
  }) async {
    final Map<String, int> result = <String, int>{};
    for (final String convId in lastReadByConversation.keys) {
      result[convId] = 0;
    }
    if (lastReadByConversation.isEmpty) return result;

    final List<String> ids = lastReadByConversation.keys.toList();
    // Берём минимальный last_read_at для оптимизации одного запроса.
    final List<DateTime> readDates = lastReadByConversation.values
        .where((DateTime? d) => d != null)
        .cast<DateTime>()
        .toList();
    final DateTime since = readDates.isEmpty
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : readDates.reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);

    final List<dynamic> rows = await _client
        .from('messages')
        .select('conversation_id,sender_id,created_at')
        .inFilter('conversation_id', ids)
        .neq('sender_id', currentUserId)
        .isFilter('deleted_at', null)
        .gte('created_at', since.toUtc().toIso8601String());

    for (final dynamic raw in rows) {
      final Map<String, dynamic> row = raw as Map<String, dynamic>;
      final String convId = row['conversation_id'] as String;
      final DateTime? lastRead = lastReadByConversation[convId];
      final DateTime ts = DateTime.parse(row['created_at'] as String);
      if (lastRead == null || ts.isAfter(lastRead)) {
        result[convId] = (result[convId] ?? 0) + 1;
      }
    }
    return result;
  }

  /// Создаёт DM или возвращает существующий.
  Future<ConversationModel> createOrGetDm(
    String currentUserId,
    String peerId,
  ) async {
    if (currentUserId == peerId) {
      throw const AppException('Нельзя начать диалог с самим собой');
    }
    final bool firstIsUser1 = currentUserId.compareTo(peerId) < 0;
    final String user1 = firstIsUser1 ? currentUserId : peerId;
    final String user2 = firstIsUser1 ? peerId : currentUserId;

    final List<dynamic> existing = await _client
        .from('conversations')
        .select(_convSelect)
        .eq('kind', 'dm')
        .eq('user1_id', user1)
        .eq('user2_id', user2)
        .limit(1);
    if (existing.isNotEmpty) {
      return ConversationModel.fromJson(existing.first as Map<String, dynamic>);
    }

    await _client.from('conversations').insert(<String, dynamic>{
      'kind': 'dm',
      'user1_id': user1,
      'user2_id': user2,
    });
    final Map<String, dynamic> created = await _client
        .from('conversations')
        .select(_convSelect)
        .eq('kind', 'dm')
        .eq('user1_id', user1)
        .eq('user2_id', user2)
        .single();
    return ConversationModel.fromJson(created);
  }

  /// Создаёт группу через RPC; возвращает её id.
  Future<String> createGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    final dynamic raw = await _client.rpc<dynamic>(
      'fn_create_group',
      params: <String, dynamic>{
        'p_title': title,
        'p_member_ids': memberIds,
      },
    );
    if (raw is String) return raw;
    throw const AppException('Не удалось создать группу');
  }

  /// Возвращает (или создаёт) Saved Messages id.
  Future<String> createOrGetSaved() async {
    final dynamic raw = await _client.rpc<dynamic>('fn_create_saved');
    if (raw is String) return raw;
    throw const AppException('Не удалось создать Saved Messages');
  }

  Future<ConversationModel> getConversationById(String id) async {
    final Map<String, dynamic> raw = await _client
        .from('conversations')
        .select(_convSelect)
        .eq('id', id)
        .single();
    return ConversationModel.fromJson(raw);
  }

  Future<void> addMember({
    required String conversationId,
    required String userId,
    String role = 'member',
  }) =>
      _client.rpc<void>('fn_add_member', params: <String, dynamic>{
        'p_conv_id': conversationId,
        'p_user_id': userId,
        'p_role': role,
      });

  Future<void> removeMember({
    required String conversationId,
    required String userId,
  }) =>
      _client.rpc<void>('fn_remove_member', params: <String, dynamic>{
        'p_conv_id': conversationId,
        'p_user_id': userId,
      });

  Future<void> changeRole({
    required String conversationId,
    required String userId,
    required String role,
  }) =>
      _client.rpc<void>('fn_change_role', params: <String, dynamic>{
        'p_conv_id': conversationId,
        'p_user_id': userId,
        'p_role': role,
      });

  Future<void> setGroupTitle({
    required String conversationId,
    required String title,
  }) =>
      _client.rpc<void>('fn_set_group_title', params: <String, dynamic>{
        'p_conv_id': conversationId,
        'p_title': title,
      });

  Future<void> setGroupAvatar({
    required String conversationId,
    required String? path,
  }) =>
      _client.rpc<void>('fn_set_group_avatar', params: <String, dynamic>{
        'p_conv_id': conversationId,
        'p_path': path,
      });

  Future<void> markRead(String conversationId) =>
      _client.rpc<void>('fn_mark_conv_read', params: <String, dynamic>{
        'p_conv_id': conversationId,
      });

  Future<void> setSelfDestruct({
    required String conversationId,
    required int seconds,
  }) =>
      _client.rpc<void>('fn_set_self_destruct', params: <String, dynamic>{
        'p_conv_id': conversationId,
        'p_seconds': seconds,
      });

  /// Включает/выключает mute для текущего юзера в conversation_members.
  /// `until == null` — снять mute.
  Future<void> setMute({
    required String conversationId,
    required DateTime? until,
  }) =>
      _client.rpc<void>('fn_set_mute', params: <String, dynamic>{
        'p_conv_id': conversationId,
        'p_until': until?.toUtc().toIso8601String(),
      });

  /// Любое изменение, касающееся диалогов — рефетч списка.
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
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversation_members',
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

/// Утилита для конвертации сырых моделей в готовые сущности.
class ConversationHydrator {
  /// Реэкспорт ProfileModel.toEntity на случай, если репозиторию нужен доступ.
  static ProfileModel? pickPeer({
    required String currentUserId,
    required List<ConversationMemberModel> members,
  }) {
    for (final ConversationMemberModel m in members) {
      if (m.userId != currentUserId && m.profile != null) return m.profile;
    }
    return null;
  }

  static MessageModel? lastMessageOf(ConversationModel c) => c.lastMessage;
}
