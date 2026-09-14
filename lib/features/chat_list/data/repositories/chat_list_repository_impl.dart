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

  bool _isCurrentAccount(String accountId) =>
      client.auth.currentUser?.id == accountId;

  void _ensureCurrentAccount(String accountId) {
    if (!_isCurrentAccount(accountId)) {
      throw const app.AuthException('Сессия изменилась');
    }
  }

  @override
  Future<List<ConversationEntity>> getConversations() async {
    final String accountId = _uid;
    try {
      _ensureCurrentAccount(accountId);
      final List<String> ids = await remote.getConversationIds(accountId);
      _ensureCurrentAccount(accountId);
      if (ids.isEmpty) {
        _ensureCurrentAccount(accountId);
        await local.cache(accountId, <ConversationEntity>[]);
        _ensureCurrentAccount(accountId);
        return <ConversationEntity>[];
      }
      _ensureCurrentAccount(accountId);
      final List<ConversationModel> convs =
          await remote.getConversationsByIds(ids);
      _ensureCurrentAccount(accountId);
      final List<ConversationMemberModel> members =
          await remote.getMembersForConversations(ids);
      _ensureCurrentAccount(accountId);

      final Map<String, List<ConversationMemberModel>> byConv =
          <String, List<ConversationMemberModel>>{};
      DateTime? myLastRead(String convId) {
        for (final ConversationMemberModel m in byConv[convId] ?? const []) {
          if (m.userId == accountId) return m.lastReadAt;
        }
        return null;
      }

      for (final ConversationMemberModel m in members) {
        byConv
            .putIfAbsent(
              m.conversationId,
              () => <ConversationMemberModel>[],
            )
            .add(m);
      }

      final Map<String, DateTime?> lastReadByConv = <String, DateTime?>{};
      for (final ConversationModel c in convs) {
        lastReadByConv[c.id] = myLastRead(c.id);
      }
      _ensureCurrentAccount(accountId);
      final Map<String, int> unread = await remote.getUnreadCounts(
        currentUserId: accountId,
        lastReadByConversation: lastReadByConv,
      );
      _ensureCurrentAccount(accountId);

      final List<ConversationEntity> entities = convs
          .map((ConversationModel c) => _toEntity(
                c,
                byConv[c.id] ?? const <ConversationMemberModel>[],
                unread[c.id] ?? 0,
                accountId: accountId,
              ))
          .toList();
      _ensureCurrentAccount(accountId);
      await local.cache(accountId, entities);
      _ensureCurrentAccount(accountId);
      return entities;
    } on app.AuthException {
      rethrow;
    } catch (_) {
      _ensureCurrentAccount(accountId);
      final List<ConversationEntity> cached = await local.getCached(accountId);
      _ensureCurrentAccount(accountId);
      return cached;
    }
  }

  @override
  Future<ConversationEntity> createOrGetDm(String peerId) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    final ConversationModel model =
        await remote.createOrGetDm(accountId, peerId);
    _ensureCurrentAccount(accountId);
    final List<ConversationMemberModel> members =
        await remote.getMembersForConversations(<String>[model.id]);
    _ensureCurrentAccount(accountId);
    final ConversationEntity entity =
        _toEntity(model, members, 0, accountId: accountId);
    _ensureCurrentAccount(accountId);
    return entity;
  }

  @override
  Future<ConversationEntity> createGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    final String id = await remote.createGroup(
      title: title,
      memberIds: memberIds,
    );
    _ensureCurrentAccount(accountId);
    final ConversationModel model = await remote.getConversationById(id);
    _ensureCurrentAccount(accountId);
    final List<ConversationMemberModel> members =
        await remote.getMembersForConversations(<String>[id]);
    _ensureCurrentAccount(accountId);
    final ConversationEntity entity =
        _toEntity(model, members, 0, accountId: accountId);
    _ensureCurrentAccount(accountId);
    return entity;
  }

  @override
  Future<ConversationEntity> createOrGetSaved() async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    final String id = await remote.createOrGetSaved();
    _ensureCurrentAccount(accountId);
    final ConversationModel model = await remote.getConversationById(id);
    _ensureCurrentAccount(accountId);
    final List<ConversationMemberModel> members =
        await remote.getMembersForConversations(<String>[id]);
    _ensureCurrentAccount(accountId);
    final ConversationEntity entity =
        _toEntity(model, members, 0, accountId: accountId);
    _ensureCurrentAccount(accountId);
    return entity;
  }

  @override
  Future<void> addMember({
    required String conversationId,
    required String userId,
    String role = 'member',
  }) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.addMember(
      conversationId: conversationId,
      userId: userId,
      role: role,
    );
    _ensureCurrentAccount(accountId);
  }

  @override
  Future<void> removeMember({
    required String conversationId,
    required String userId,
  }) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.removeMember(conversationId: conversationId, userId: userId);
    _ensureCurrentAccount(accountId);
  }

  @override
  Future<void> changeRole({
    required String conversationId,
    required String userId,
    required String role,
  }) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.changeRole(
      conversationId: conversationId,
      userId: userId,
      role: role,
    );
    _ensureCurrentAccount(accountId);
  }

  @override
  Future<void> setGroupTitle({
    required String conversationId,
    required String title,
  }) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.setGroupTitle(conversationId: conversationId, title: title);
    _ensureCurrentAccount(accountId);
  }

  @override
  Future<void> setGroupAvatar({
    required String conversationId,
    required String? path,
  }) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.setGroupAvatar(conversationId: conversationId, path: path);
    _ensureCurrentAccount(accountId);
  }

  @override
  Future<void> leaveConversation(String conversationId) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.removeMember(
        conversationId: conversationId, userId: accountId);
    _ensureCurrentAccount(accountId);
  }

  @override
  Future<void> markRead(String conversationId) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.markRead(conversationId);
    _ensureCurrentAccount(accountId);
  }

  @override
  Future<void> setSelfDestruct({
    required String conversationId,
    required int seconds,
  }) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.setSelfDestruct(
      conversationId: conversationId,
      seconds: seconds,
    );
    _ensureCurrentAccount(accountId);
  }

  @override
  Future<void> setMute({
    required String conversationId,
    required DateTime? until,
  }) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.setMute(conversationId: conversationId, until: until);
    _ensureCurrentAccount(accountId);
  }

  @override
  Stream<void> watchConversationChanges() async* {
    final String accountId = _uid;
    if (!_isCurrentAccount(accountId)) return;
    await for (final _ in remote.watchChanges(accountId)) {
      if (!_isCurrentAccount(accountId)) return;
      yield null;
    }
  }

  // ---------------------------------------------------------------------------

  ConversationEntity _toEntity(
    ConversationModel c,
    List<ConversationMemberModel> members,
    int unread, {
    required String accountId,
  }) {
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
        if (m.profile.id != accountId) {
          peer = m.profile;
          break;
        }
      }
      // Fallback на user1/user2 (на случай неполного embedding).
      if (peer == null) {
        final String? otherId = c.user1Id == accountId ? c.user2Id : c.user1Id;
        if (otherId != null) {
          peer = ProfileEntity(id: otherId, username: '');
        }
      }
    }

    final DateTime now = DateTime.now();
    final ConversationMember? me =
        hydratedMembers.cast<ConversationMember?>().firstWhere(
              (ConversationMember? m) => m?.profile.id == accountId,
              orElse: () => null,
            );
    final bool muted = me?.mutedUntil != null && me!.mutedUntil!.isAfter(now);

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
