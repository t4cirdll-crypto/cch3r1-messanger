import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart' as app;
import '../../../auth/domain/entities/profile_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/repositories/chat_list_repository.dart';
import '../datasources/chat_list_local_datasource.dart';
import '../datasources/chat_list_remote_datasource.dart';
import '../models/conversation_model.dart';

class ChatListRepositoryImpl implements ChatListRepository {
  ChatListRepositoryImpl({
    required this.remote,
    required this.local,
    required this.client,
  });

  final ChatListRemoteDataSource remote;
  final ChatListLocalDataSource local;
  final SupabaseClient client;

  String get _uid {
    final User? u = client.auth.currentUser;
    if (u == null) throw const app.AuthException('Нет активной сессии');
    return u.id;
  }

  @override
  Future<List<ConversationEntity>> getConversations() async {
    try {
      final List<String> ids = await remote.getConversationIds(_uid);
      if (ids.isEmpty) {
        await local.cache(<ConversationEntity>[]);
        return <ConversationEntity>[];
      }
      final List<ConversationModel> convs =
          await remote.getConversationsByIds(ids);
      final List<ConversationMemberModel> members =
          await remote.getMembersForConversations(ids);

      final Map<String, List<ConversationMemberModel>> byConv =
          <String, List<ConversationMemberModel>>{};
      DateTime? myLastRead(String convId) {
        for (final ConversationMemberModel m in byConv[convId] ?? const []) {
          if (m.userId == _uid) return m.lastReadAt;
        }
        return null;
      }

      for (final ConversationMemberModel m in members) {
        byConv.putIfAbsent(
          m.conversationId,
          () => <ConversationMemberModel>[],
        ).add(m);
      }

      final Map<String, DateTime?> lastReadByConv = <String, DateTime?>{};
      for (final ConversationModel c in convs) {
        lastReadByConv[c.id] = myLastRead(c.id);
      }
      final Map<String, int> unread = await remote.getUnreadCounts(
        currentUserId: _uid,
        lastReadByConversation: lastReadByConv,
      );

      final List<ConversationEntity> entities = convs
          .map((ConversationModel c) => _toEntity(
                c,
                byConv[c.id] ?? const <ConversationMemberModel>[],
                unread[c.id] ?? 0,
              ))
          .toList();
      await local.cache(entities);
      return entities;
    } catch (_) {
      return local.getCached();
    }
  }

  @override
  Future<ConversationEntity> createOrGetDm(String peerId) async {
    final ConversationModel model = await remote.createOrGetDm(_uid, peerId);
    final List<ConversationMemberModel> members =
        await remote.getMembersForConversations(<String>[model.id]);
    return _toEntity(model, members, 0);
  }

  @override
  Future<ConversationEntity> createGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    final String id = await remote.createGroup(
      title: title,
      memberIds: memberIds,
    );
    final ConversationModel model = await remote.getConversationById(id);
    final List<ConversationMemberModel> members =
        await remote.getMembersForConversations(<String>[id]);
    return _toEntity(model, members, 0);
  }

  @override
  Future<ConversationEntity> createOrGetSaved() async {
    final String id = await remote.createOrGetSaved();
    final ConversationModel model = await remote.getConversationById(id);
    final List<ConversationMemberModel> members =
        await remote.getMembersForConversations(<String>[id]);
    return _toEntity(model, members, 0);
  }

  @override
  Future<void> addMember({
    required String conversationId,
    required String userId,
    String role = 'member',
  }) =>
      remote.addMember(
        conversationId: conversationId,
        userId: userId,
        role: role,
      );

  @override
  Future<void> removeMember({
    required String conversationId,
    required String userId,
  }) =>
      remote.removeMember(conversationId: conversationId, userId: userId);

  @override
  Future<void> changeRole({
    required String conversationId,
    required String userId,
    required String role,
  }) =>
      remote.changeRole(
        conversationId: conversationId,
        userId: userId,
        role: role,
      );

  @override
  Future<void> setGroupTitle({
    required String conversationId,
    required String title,
  }) =>
      remote.setGroupTitle(conversationId: conversationId, title: title);

  @override
  Future<void> setGroupAvatar({
    required String conversationId,
    required String? path,
  }) =>
      remote.setGroupAvatar(conversationId: conversationId, path: path);

  @override
  Future<void> leaveConversation(String conversationId) =>
      remote.removeMember(conversationId: conversationId, userId: _uid);

  @override
  Future<void> markRead(String conversationId) =>
      remote.markRead(conversationId);

  @override
  Future<void> setSelfDestruct({
    required String conversationId,
    required int seconds,
  }) =>
      remote.setSelfDestruct(
        conversationId: conversationId,
        seconds: seconds,
      );

  @override
  Future<void> setMute({
    required String conversationId,
    required DateTime? until,
  }) =>
      remote.setMute(conversationId: conversationId, until: until);

  @override
  Stream<void> watchConversationChanges() => remote.watchChanges(_uid);

  // ---------------------------------------------------------------------------

  ConversationEntity _toEntity(
    ConversationModel c,
    List<ConversationMemberModel> members,
    int unread,
  ) {
    final ConversationKind kind = ConversationKind.fromString(c.kind);
    final List<ConversationMember> hydratedMembers = members
        .where((ConversationMemberModel m) => m.profile != null)
        .map((ConversationMemberModel m) => ConversationMember(
              profile: m.profile!.toEntity(),
              role: MemberRole.fromString(m.role),
              joinedAt: m.joinedAt,
              lastReadAt: m.lastReadAt,
              mutedUntil: m.mutedUntil,
            ))
        .toList(growable: false);

    ProfileEntity? peer;
    if (kind == ConversationKind.dm) {
      for (final ConversationMember m in hydratedMembers) {
        if (m.profile.id != _uid) {
          peer = m.profile;
          break;
        }
      }
      // Fallback на user1/user2 (на случай неполного embedding).
      if (peer == null) {
        final String? otherId = c.user1Id == _uid ? c.user2Id : c.user1Id;
        if (otherId != null) {
          peer = ProfileEntity(id: otherId, username: '');
        }
      }
    }

    final DateTime now = DateTime.now();
    final ConversationMember? me = hydratedMembers
        .cast<ConversationMember?>()
        .firstWhere(
          (ConversationMember? m) => m?.profile.id == _uid,
          orElse: () => null,
        );
    final bool muted =
        me?.mutedUntil != null && me!.mutedUntil!.isAfter(now);

    return ConversationEntity(
      id: c.id,
      kind: kind,
      title: c.title,
      avatarPath: c.avatarPath,
      updatedAt: c.updatedAt,
      members: hydratedMembers,
      peer: peer,
      lastMessage: c.lastMessage?.toEntity(),
      unreadCount: unread,
      muted: muted,
      selfDestructSeconds: c.selfDestructSeconds,
    );
  }
}


