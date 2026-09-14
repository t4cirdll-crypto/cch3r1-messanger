import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/exceptions.dart' as app;
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_local_datasource.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/message_model.dart';
import '../models/reaction_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required this.remote,
    required this.local,
    required this.client,
  });

  final ChatRemoteDataSource remote;
  final ChatLocalDataSource local;
  final SupabaseClient client;

  static const Uuid _uuid = Uuid();

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

  Future<List<MessageEntity>> _hydrate(
    List<MessageModel> models, {
    required String accountId,
    bool refreshReactions = true,
  }) async {
    _ensureCurrentAccount(accountId);
    if (models.isEmpty) return <MessageEntity>[];
    final List<String> ids = models.map((MessageModel m) => m.id).toList();

    // Загружаем реакции (с обновлением кэша при онлайне).
    List<ReactionModel> reactions;
    if (refreshReactions) {
      try {
        _ensureCurrentAccount(accountId);
        reactions = await remote.getReactionsForMessages(ids);
        _ensureCurrentAccount(accountId);
        await local.upsertReactions(accountId, reactions);
        _ensureCurrentAccount(accountId);
      } on app.AuthException {
        rethrow;
      } catch (_) {
        _ensureCurrentAccount(accountId);
        reactions = await local.getReactions(accountId, ids);
        _ensureCurrentAccount(accountId);
      }
    } else {
      _ensureCurrentAccount(accountId);
      reactions = await local.getReactions(accountId, ids);
      _ensureCurrentAccount(accountId);
    }

    final Map<String, List<ReactionModel>> reactionsByMsg =
        <String, List<ReactionModel>>{};
    for (final ReactionModel r in reactions) {
      reactionsByMsg.putIfAbsent(r.messageId, () => <ReactionModel>[]).add(r);
    }

    // Reply-to: грузим все недостающие сообщения по id (могут быть и старые,
    // которых нет в первой странице).
    final Set<String> replyIds =
        models.map((MessageModel m) => m.replyToId).whereType<String>().toSet();
    final Map<String, MessageModel> replyMap = <String, MessageModel>{};
    if (replyIds.isNotEmpty) {
      // Сначала заглядываем в локальный кэш.
      final List<String> missing = <String>[];
      for (final String id in replyIds) {
        _ensureCurrentAccount(accountId);
        final MessageModel? cached = await local.getById(accountId, id);
        _ensureCurrentAccount(accountId);
        if (cached != null) {
          replyMap[id] = cached;
        } else {
          missing.add(id);
        }
      }
      if (missing.isNotEmpty) {
        try {
          _ensureCurrentAccount(accountId);
          final List<MessageModel> fetched =
              await remote.getMessagesByIds(missing);
          _ensureCurrentAccount(accountId);
          for (final MessageModel m in fetched) {
            replyMap[m.id] = m;
            _ensureCurrentAccount(accountId);
            await local.upsert(accountId, m);
            _ensureCurrentAccount(accountId);
          }
        } on app.AuthException {
          rethrow;
        } catch (_) {
          _ensureCurrentAccount(accountId);
        }
      }
    }

    _ensureCurrentAccount(accountId);

    return models.map((MessageModel m) {
      final List<ReactionEntity> aggregated =
          _aggregateReactions(reactionsByMsg[m.id] ?? const <ReactionModel>[]);
      final MessageModel? reply =
          m.replyToId == null ? null : replyMap[m.replyToId];
      return m.toEntity(
        replyTo: reply?.toEntity(),
        reactions: aggregated,
      );
    }).toList();
  }

  static List<ReactionEntity> _aggregateReactions(List<ReactionModel> raw) {
    if (raw.isEmpty) return const <ReactionEntity>[];
    final Map<String, List<String>> byEmoji = <String, List<String>>{};
    for (final ReactionModel r in raw) {
      byEmoji.putIfAbsent(r.emoji, () => <String>[]).add(r.userId);
    }
    final List<ReactionEntity> out = byEmoji.entries
        .map((MapEntry<String, List<String>> e) =>
            ReactionEntity(emoji: e.key, userIds: e.value))
        .toList()
      ..sort((ReactionEntity a, ReactionEntity b) {
        final int c = b.count.compareTo(a.count);
        if (c != 0) return c;
        return a.emoji.compareTo(b.emoji);
      });
    return out;
  }

  @override
  Future<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 30,
    DateTime? before,
  }) async {
    final String accountId = _uid;
    try {
      _ensureCurrentAccount(accountId);
      final List<MessageModel> remoteList = await remote.getMessages(
        conversationId,
        limit: limit,
        before: before,
      );
      _ensureCurrentAccount(accountId);
      if (before == null) {
        await local.cacheAll(accountId, conversationId, remoteList);
        _ensureCurrentAccount(accountId);
      }
      final List<MessageEntity> hydrated =
          await _hydrate(remoteList, accountId: accountId);
      _ensureCurrentAccount(accountId);
      return hydrated;
    } on app.AuthException {
      rethrow;
    } catch (_) {
      _ensureCurrentAccount(accountId);
      if (before != null) {
        return <MessageEntity>[];
      }
      final List<MessageModel> cached =
          await local.getMessages(accountId, conversationId);
      _ensureCurrentAccount(accountId);
      final List<MessageEntity> hydrated = await _hydrate(
        cached,
        accountId: accountId,
        refreshReactions: false,
      );
      _ensureCurrentAccount(accountId);
      return hydrated;
    }
  }

  @override
  Future<MessageEntity> sendMessage({
    required String conversationId,
    String? content,
    OutgoingAttachment? attachment,
    String? replyToId,
    String? forwardedFromMessageId,
    String? forwardedFromSenderId,
  }) async {
    final String accountId = _uid;
    AttachmentUpload? uploaded;
    if (attachment != null) {
      final String storagePath;
      if (attachment.remoteUrl != null) {
        // GIF / внешний URL: не грузим в storage, сохраняем как есть.
        storagePath = attachment.remoteUrl!;
      } else {
        final String messageId = _uuid.v4();
        _ensureCurrentAccount(accountId);
        storagePath = await remote.uploadAttachment(
          conversationId: conversationId,
          messageId: messageId,
          extension: attachment.extension,
          mime: attachment.mime,
          bytes: attachment.bytes,
          file: attachment.file,
        );
        _ensureCurrentAccount(accountId);
      }
      uploaded = AttachmentUpload(
        path: storagePath,
        kind: attachment.kind.value,
        name: attachment.name,
        mime: attachment.mime,
        size: attachment.size,
        durationMs: attachment.durationMs,
        width: attachment.width,
        height: attachment.height,
      );
    }

    _ensureCurrentAccount(accountId);

    final MessageModel msg = await remote.sendMessage(
      conversationId: conversationId,
      senderId: accountId,
      content: content,
      attachment: uploaded,
      replyToId: replyToId,
      forwardedFromMessageId: forwardedFromMessageId,
      forwardedFromSenderId: forwardedFromSenderId,
    );
    _ensureCurrentAccount(accountId);
    await local.upsert(accountId, msg);
    _ensureCurrentAccount(accountId);

    MessageEntity? reply;
    if (msg.replyToId != null) {
      _ensureCurrentAccount(accountId);
      final MessageModel? r = await local.getById(accountId, msg.replyToId!);
      _ensureCurrentAccount(accountId);
      reply = r?.toEntity();
    }
    _ensureCurrentAccount(accountId);
    return msg.toEntity(replyTo: reply);
  }

  @override
  Future<void> editMessage({
    required String messageId,
    required String content,
  }) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.editMessage(messageId: messageId, content: content);
    _ensureCurrentAccount(accountId);
    final MessageModel? cached = await local.getById(accountId, messageId);
    _ensureCurrentAccount(accountId);
    if (cached != null) {
      _ensureCurrentAccount(accountId);
      await local.upsert(
          accountId,
          cached.copyWith(
            content: content.trim(),
            editedAt: DateTime.now(),
          ));
      _ensureCurrentAccount(accountId);
    }
  }

  @override
  Future<void> deleteForAll(String messageId) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.deleteForAll(messageId);
    _ensureCurrentAccount(accountId);
    final MessageModel? cached = await local.getById(accountId, messageId);
    _ensureCurrentAccount(accountId);
    if (cached != null) {
      _ensureCurrentAccount(accountId);
      await local.upsert(
          accountId,
          cached.copyWith(
            content: null,
            deletedAt: DateTime.now(),
            editedAt: null,
            attachmentPath: null,
            attachmentKind: null,
            attachmentName: null,
            attachmentMime: null,
            attachmentSize: null,
            attachmentDurationMs: null,
            attachmentWidth: null,
            attachmentHeight: null,
          ));
      _ensureCurrentAccount(accountId);
    }
  }

  @override
  Future<void> deleteForMe(String messageId) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await local.delete(accountId, messageId);
    _ensureCurrentAccount(accountId);
  }

  @override
  Future<void> setPin({required String messageId, required bool pinned}) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.setPin(messageId: messageId, pinned: pinned);
    _ensureCurrentAccount(accountId);
    final MessageModel? cached = await local.getById(accountId, messageId);
    _ensureCurrentAccount(accountId);
    if (cached != null) {
      _ensureCurrentAccount(accountId);
      await local.upsert(
          accountId,
          cached.copyWith(
            pinnedAt: pinned ? DateTime.now() : null,
          ));
      _ensureCurrentAccount(accountId);
    }
  }

  @override
  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    final List<ReactionModel> existing =
        await local.getReactions(accountId, <String>[messageId]);
    _ensureCurrentAccount(accountId);
    final bool mine = existing.any(
      (ReactionModel r) => r.userId == accountId && r.emoji == emoji,
    );
    if (mine) {
      _ensureCurrentAccount(accountId);
      await remote.removeReaction(
          messageId: messageId, userId: accountId, emoji: emoji);
      _ensureCurrentAccount(accountId);
      await local.deleteReaction(
          accountId: accountId,
          messageId: messageId,
          userId: accountId,
          emoji: emoji);
      _ensureCurrentAccount(accountId);
    } else {
      _ensureCurrentAccount(accountId);
      await remote.addReaction(
          messageId: messageId, userId: accountId, emoji: emoji);
      _ensureCurrentAccount(accountId);
      await local.upsertReaction(
          accountId,
          ReactionModel(
            messageId: messageId,
            userId: accountId,
            emoji: emoji,
            createdAt: DateTime.now(),
          ));
      _ensureCurrentAccount(accountId);
    }
  }

  @override
  Future<List<MessageEntity>> searchInConversation({
    required String conversationId,
    required String query,
  }) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    final List<MessageModel> result = await remote.searchInConversation(
      conversationId: conversationId,
      query: query,
    );
    _ensureCurrentAccount(accountId);
    final List<MessageEntity> hydrated =
        await _hydrate(result, accountId: accountId);
    _ensureCurrentAccount(accountId);
    return hydrated;
  }

  @override
  Future<List<MessageEntity>> getPinnedMessages(String conversationId) async {
    final String accountId = _uid;
    try {
      _ensureCurrentAccount(accountId);
      final List<MessageModel> remoteList =
          await remote.getPinnedMessages(conversationId);
      _ensureCurrentAccount(accountId);
      for (final MessageModel m in remoteList) {
        _ensureCurrentAccount(accountId);
        await local.upsert(accountId, m);
        _ensureCurrentAccount(accountId);
      }
      final List<MessageEntity> hydrated =
          await _hydrate(remoteList, accountId: accountId);
      _ensureCurrentAccount(accountId);
      return hydrated;
    } on app.AuthException {
      rethrow;
    } catch (_) {
      _ensureCurrentAccount(accountId);
      final List<MessageModel> cached =
          await local.getMessages(accountId, conversationId);
      _ensureCurrentAccount(accountId);
      final List<MessageModel> filtered = cached
          .where((MessageModel m) => m.pinnedAt != null && m.deletedAt == null)
          .toList();
      final List<MessageEntity> hydrated = await _hydrate(
        filtered,
        accountId: accountId,
        refreshReactions: false,
      );
      _ensureCurrentAccount(accountId);
      return hydrated;
    }
  }

  @override
  Future<String> getAttachmentSignedUrl(String storagePath) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    final String signedUrl = await remote.createSignedUrl(storagePath);
    _ensureCurrentAccount(accountId);
    return signedUrl;
  }

  @override
  Future<void> markAsRead(String conversationId) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.markAsRead(
      conversationId: conversationId,
      currentUserId: accountId,
    );
    _ensureCurrentAccount(accountId);
  }

  @override
  Stream<MessageEntity> watchMessages(String conversationId) async* {
    final String accountId = _uid;
    if (!_isCurrentAccount(accountId)) return;
    await for (final MessageStreamEvent event
        in remote.watchMessages(conversationId)) {
      if (!_isCurrentAccount(accountId)) return;
      final MessageModel? m = event.upserted;
      if (m == null) continue;
      await local.upsert(accountId, m);
      if (!_isCurrentAccount(accountId)) return;
      MessageEntity? reply;
      if (m.replyToId != null) {
        final MessageModel? r = await local.getById(accountId, m.replyToId!);
        if (!_isCurrentAccount(accountId)) return;
        reply = r?.toEntity();
      }
      final List<ReactionModel> rs =
          await local.getReactions(accountId, <String>[m.id]);
      if (!_isCurrentAccount(accountId)) return;
      yield m.toEntity(
        replyTo: reply,
        reactions: _aggregateReactions(rs),
      );
    }
  }

  @override
  Stream<String> watchMessageDeletes(String conversationId) async* {
    // Используем тот же канал, что и watchMessages, но фильтруем только
    // delete-события. Каналы получаются разные (broadcast streams), это ок.
    final String accountId = _uid;
    if (!_isCurrentAccount(accountId)) return;
    await for (final MessageStreamEvent event
        in remote.watchMessages(conversationId)) {
      if (!_isCurrentAccount(accountId)) return;
      final String? id = event.deletedId;
      if (id == null) continue;
      await local.delete(accountId, id);
      if (!_isCurrentAccount(accountId)) return;
      yield id;
    }
  }

  @override
  Future<int> sweepExpiredMessages() async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    final int deletedCount = await remote.sweepExpiredMessages();
    _ensureCurrentAccount(accountId);
    return deletedCount;
  }

  @override
  Stream<ReactionDelta> watchReactions() async* {
    final String accountId = _uid;
    if (!_isCurrentAccount(accountId)) return;
    await for (final ReactionEvent e in remote.watchReactions()) {
      if (!_isCurrentAccount(accountId)) return;
      if (e.type == ReactionEventType.added) {
        await local.upsertReaction(accountId, e.reaction);
        if (!_isCurrentAccount(accountId)) return;
      } else {
        await local.deleteReaction(
          accountId: accountId,
          messageId: e.reaction.messageId,
          userId: e.reaction.userId,
          emoji: e.reaction.emoji,
        );
        if (!_isCurrentAccount(accountId)) return;
      }
      if (!_isCurrentAccount(accountId)) return;
      yield ReactionDelta(
        messageId: e.reaction.messageId,
        userId: e.reaction.userId,
        emoji: e.reaction.emoji,
        added: e.type == ReactionEventType.added,
      );
    }
  }
}
