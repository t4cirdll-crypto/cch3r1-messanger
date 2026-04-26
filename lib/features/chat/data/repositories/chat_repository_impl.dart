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

  Future<List<MessageEntity>> _hydrate(
    List<MessageModel> models, {
    bool refreshReactions = true,
  }) async {
    if (models.isEmpty) return <MessageEntity>[];
    final List<String> ids = models.map((MessageModel m) => m.id).toList();

    // Загружаем реакции (с обновлением кэша при онлайне).
    List<ReactionModel> reactions;
    if (refreshReactions) {
      try {
        reactions = await remote.getReactionsForMessages(ids);
        await local.upsertReactions(reactions);
      } catch (_) {
        reactions = await local.getReactions(ids);
      }
    } else {
      reactions = await local.getReactions(ids);
    }

    final Map<String, List<ReactionModel>> reactionsByMsg =
        <String, List<ReactionModel>>{};
    for (final ReactionModel r in reactions) {
      reactionsByMsg.putIfAbsent(r.messageId, () => <ReactionModel>[]).add(r);
    }

    // Reply-to: грузим все недостающие сообщения по id (могут быть и старые,
    // которых нет в первой странице).
    final Set<String> replyIds = models
        .map((MessageModel m) => m.replyToId)
        .whereType<String>()
        .toSet();
    final Map<String, MessageModel> replyMap = <String, MessageModel>{};
    if (replyIds.isNotEmpty) {
      // Сначала заглядываем в локальный кэш.
      final List<String> missing = <String>[];
      for (final String id in replyIds) {
        final MessageModel? cached = await local.getById(id);
        if (cached != null) {
          replyMap[id] = cached;
        } else {
          missing.add(id);
        }
      }
      if (missing.isNotEmpty) {
        try {
          final List<MessageModel> fetched = await remote.getMessagesByIds(missing);
          for (final MessageModel m in fetched) {
            replyMap[m.id] = m;
            await local.upsert(m);
          }
        } catch (_) {/* офлайн — просто пропускаем превью */}
      }
    }

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
    try {
      final List<MessageModel> remoteList = await remote.getMessages(
        conversationId,
        limit: limit,
        before: before,
      );
      if (before == null) {
        await local.cacheAll(conversationId, remoteList);
      }
      return _hydrate(remoteList);
    } catch (_) {
      if (before != null) return <MessageEntity>[];
      final List<MessageModel> cached = await local.getMessages(conversationId);
      return _hydrate(cached, refreshReactions: false);
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
    AttachmentUpload? uploaded;
    if (attachment != null) {
      final String storagePath;
      if (attachment.remoteUrl != null) {
        // GIF / внешний URL: не грузим в storage, сохраняем как есть.
        storagePath = attachment.remoteUrl!;
      } else {
        final String messageId = _uuid.v4();
        storagePath = await remote.uploadAttachment(
          conversationId: conversationId,
          messageId: messageId,
          extension: attachment.extension,
          mime: attachment.mime,
          bytes: attachment.bytes,
          file: attachment.file,
        );
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

    final MessageModel msg = await remote.sendMessage(
      conversationId: conversationId,
      senderId: _uid,
      content: content,
      attachment: uploaded,
      replyToId: replyToId,
      forwardedFromMessageId: forwardedFromMessageId,
      forwardedFromSenderId: forwardedFromSenderId,
    );
    await local.upsert(msg);

    MessageEntity? reply;
    if (msg.replyToId != null) {
      final MessageModel? r = await local.getById(msg.replyToId!);
      reply = r?.toEntity();
    }
    return msg.toEntity(replyTo: reply);
  }

  @override
  Future<void> editMessage({
    required String messageId,
    required String content,
  }) async {
    await remote.editMessage(messageId: messageId, content: content);
    final MessageModel? cached = await local.getById(messageId);
    if (cached != null) {
      await local.upsert(cached.copyWith(
        content: content.trim(),
        editedAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<void> deleteForAll(String messageId) async {
    await remote.deleteForAll(messageId);
    final MessageModel? cached = await local.getById(messageId);
    if (cached != null) {
      await local.upsert(cached.copyWith(
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
    }
  }

  @override
  Future<void> deleteForMe(String messageId) async {
    await local.delete(messageId);
  }

  @override
  Future<void> setPin({required String messageId, required bool pinned}) async {
    await remote.setPin(messageId: messageId, pinned: pinned);
    final MessageModel? cached = await local.getById(messageId);
    if (cached != null) {
      await local.upsert(cached.copyWith(
        pinnedAt: pinned ? DateTime.now() : null,
      ));
    }
  }

  @override
  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    final String userId = _uid;
    final List<ReactionModel> existing = await local.getReactions(<String>[messageId]);
    final bool mine = existing.any(
      (ReactionModel r) => r.userId == userId && r.emoji == emoji,
    );
    if (mine) {
      await remote.removeReaction(
          messageId: messageId, userId: userId, emoji: emoji);
      await local.deleteReaction(
          messageId: messageId, userId: userId, emoji: emoji);
    } else {
      await remote.addReaction(
          messageId: messageId, userId: userId, emoji: emoji);
      await local.upsertReaction(ReactionModel(
        messageId: messageId,
        userId: userId,
        emoji: emoji,
        createdAt: DateTime.now(),
      ));
    }
  }

  @override
  Future<List<MessageEntity>> searchInConversation({
    required String conversationId,
    required String query,
  }) async {
    final List<MessageModel> result = await remote.searchInConversation(
      conversationId: conversationId,
      query: query,
    );
    return _hydrate(result);
  }

  @override
  Future<List<MessageEntity>> getPinnedMessages(String conversationId) async {
    try {
      final List<MessageModel> remoteList =
          await remote.getPinnedMessages(conversationId);
      for (final MessageModel m in remoteList) {
        await local.upsert(m);
      }
      return _hydrate(remoteList);
    } catch (_) {
      final List<MessageModel> cached =
          await local.getMessages(conversationId);
      final List<MessageModel> filtered = cached
          .where((MessageModel m) => m.pinnedAt != null && m.deletedAt == null)
          .toList();
      return _hydrate(filtered, refreshReactions: false);
    }
  }

  @override
  Future<String> getAttachmentSignedUrl(String storagePath) {
    return remote.createSignedUrl(storagePath);
  }

  @override
  Future<void> markAsRead(String conversationId) {
    return remote.markAsRead(
      conversationId: conversationId,
      currentUserId: _uid,
    );
  }

  @override
  Stream<MessageEntity> watchMessages(String conversationId) async* {
    await for (final MessageStreamEvent event
        in remote.watchMessages(conversationId)) {
      final MessageModel? m = event.upserted;
      if (m == null) continue;
      await local.upsert(m);
      MessageEntity? reply;
      if (m.replyToId != null) {
        final MessageModel? r = await local.getById(m.replyToId!);
        reply = r?.toEntity();
      }
      final List<ReactionModel> rs = await local.getReactions(<String>[m.id]);
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
    await for (final MessageStreamEvent event
        in remote.watchMessages(conversationId)) {
      final String? id = event.deletedId;
      if (id == null) continue;
      await local.delete(id);
      yield id;
    }
  }

  @override
  Future<int> sweepExpiredMessages() => remote.sweepExpiredMessages();

  @override
  Stream<ReactionDelta> watchReactions() async* {
    await for (final ReactionEvent e in remote.watchReactions()) {
      if (e.type == ReactionEventType.added) {
        await local.upsertReaction(e.reaction);
      } else {
        await local.deleteReaction(
          messageId: e.reaction.messageId,
          userId: e.reaction.userId,
          emoji: e.reaction.emoji,
        );
      }
      yield ReactionDelta(
        messageId: e.reaction.messageId,
        userId: e.reaction.userId,
        emoji: e.reaction.emoji,
        added: e.type == ReactionEventType.added,
      );
    }
  }
}
