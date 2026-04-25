import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/db/local_database.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../data/datasources/chat_local_datasource.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/services/typing_service.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/get_messages.dart';
import '../../domain/usecases/mark_as_read.dart';
import '../../domain/usecases/observe_messages.dart';
import '../../domain/usecases/send_message.dart';
import '../services/attachment_url_cache.dart';

final Provider<ChatRemoteDataSource> chatRemoteDataSourceProvider =
    Provider<ChatRemoteDataSource>(
  (Ref ref) => ChatRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final FutureProvider<ChatLocalDataSource> chatLocalDataSourceProvider =
    FutureProvider<ChatLocalDataSource>((Ref ref) async {
  final LocalDatabase db = await ref.watch(localDatabaseProvider);
  return ChatLocalDataSource(db);
});

final FutureProvider<ChatRepository> chatRepositoryProvider =
    FutureProvider<ChatRepository>((Ref ref) async {
  final ChatLocalDataSource local =
      await ref.watch(chatLocalDataSourceProvider.future);
  return ChatRepositoryImpl(
    remote: ref.watch(chatRemoteDataSourceProvider),
    local: local,
    client: ref.watch(supabaseClientProvider),
  );
});

final FutureProvider<GetMessages> getMessagesUseCaseProvider =
    FutureProvider<GetMessages>(
  (Ref ref) async => GetMessages(await ref.watch(chatRepositoryProvider.future)),
);
final FutureProvider<SendMessage> sendMessageUseCaseProvider =
    FutureProvider<SendMessage>(
  (Ref ref) async => SendMessage(await ref.watch(chatRepositoryProvider.future)),
);
final FutureProvider<MarkAsRead> markAsReadUseCaseProvider =
    FutureProvider<MarkAsRead>(
  (Ref ref) async => MarkAsRead(await ref.watch(chatRepositoryProvider.future)),
);
final FutureProvider<ObserveMessages> observeMessagesUseCaseProvider =
    FutureProvider<ObserveMessages>(
  (Ref ref) async =>
      ObserveMessages(await ref.watch(chatRepositoryProvider.future)),
);

/// Кэш signed URL для приватных вложений (TTL ~50 мин).
final FutureProvider<AttachmentUrlCache> attachmentUrlCacheProvider =
    FutureProvider<AttachmentUrlCache>((Ref ref) async {
  final ChatRepository repo = await ref.watch(chatRepositoryProvider.future);
  return AttachmentUrlCache(repo);
});

/// Канал «печатает…» для текущего диалога.
final AutoDisposeProviderFamily<TypingChannel, String> typingChannelProvider =
    Provider.autoDispose.family<TypingChannel, String>(
  (Ref ref, String conversationId) {
    final SupabaseClient client = ref.watch(supabaseClientProvider);
    final String selfUid = client.auth.currentUser?.id ?? '';
    final TypingChannel ch = TypingChannel(
      client: client,
      conversationId: conversationId,
      selfUserId: selfUid,
    )..connect();
    ref.onDispose(() {
      // ignore: discarded_futures
      ch.dispose();
    });
    return ch;
  },
);

/// Поток множества userId, которые сейчас печатают в указанном диалоге.
final AutoDisposeStreamProviderFamily<Set<String>, String>
    typingUsersProvider =
    StreamProvider.autoDispose.family<Set<String>, String>(
  (Ref ref, String conversationId) =>
      ref.watch(typingChannelProvider(conversationId)).typingUsers,
);

/// Состояние экрана чата.
class ChatState {
  const ChatState({
    this.messages = const <MessageEntity>[],
    this.isLoadingInitial = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<MessageEntity> messages; // сортировка ASC (старые → новые)
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  ChatState copyWith({
    List<MessageEntity>? messages,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Контроллер экрана чата: загрузка, пагинация, отправка, Realtime.
class ChatController extends FamilyAsyncNotifier<ChatState, String> {
  static const int _pageSize = 30;

  @override
  Future<ChatState> build(String conversationId) async {
    final ObserveMessages observe =
        await ref.watch(observeMessagesUseCaseProvider.future);
    final stream = observe.call(conversationId);
    final sub = stream.listen(_onIncoming);
    ref.onDispose(sub.cancel);

    final ChatRepository repo =
        await ref.watch(chatRepositoryProvider.future);
    final reactionSub =
        repo.watchReactions().listen(_onReactionDelta);
    ref.onDispose(reactionSub.cancel);

    final GetMessages uc =
        await ref.watch(getMessagesUseCaseProvider.future);
    final List<MessageEntity> page = await uc.call(
      GetMessagesParams(conversationId: conversationId, limit: _pageSize),
    );
    final List<MessageEntity> sorted = page.reversed.toList();
    return ChatState(
      messages: sorted,
      hasMore: page.length == _pageSize,
    );
  }

  void _onIncoming(MessageEntity message) {
    final ChatState? current = state.valueOrNull;
    if (current == null) return;
    final List<MessageEntity> next = List<MessageEntity>.of(current.messages);
    final int existing = next.indexWhere(
      (MessageEntity m) => m.id == message.id,
    );
    if (existing >= 0) {
      // Сохраняем уже агрегированные реакции локально, если сервер их не
      // прислал (Realtime payload реакций не содержит).
      final List<ReactionEntity> keep = message.reactions.isEmpty
          ? next[existing].reactions
          : message.reactions;
      next[existing] = message.copyWith(reactions: keep);
    } else {
      next.add(message);
      next.sort((MessageEntity a, MessageEntity b) =>
          a.createdAt.compareTo(b.createdAt));
    }
    state = AsyncData<ChatState>(current.copyWith(messages: next));
  }

  void _onReactionDelta(ReactionDelta delta) {
    final ChatState? current = state.valueOrNull;
    if (current == null) return;
    final int idx = current.messages.indexWhere(
      (MessageEntity m) => m.id == delta.messageId,
    );
    if (idx < 0) return;
    final MessageEntity msg = current.messages[idx];
    final List<ReactionEntity> updated = _applyDelta(msg.reactions, delta);
    final List<MessageEntity> next = List<MessageEntity>.of(current.messages);
    next[idx] = msg.copyWith(reactions: updated);
    state = AsyncData<ChatState>(current.copyWith(messages: next));
  }

  static List<ReactionEntity> _applyDelta(
    List<ReactionEntity> current,
    ReactionDelta delta,
  ) {
    final List<ReactionEntity> out =
        List<ReactionEntity>.of(current.map((ReactionEntity r) =>
            ReactionEntity(emoji: r.emoji, userIds: List<String>.of(r.userIds))));
    final int i = out.indexWhere((ReactionEntity r) => r.emoji == delta.emoji);
    if (delta.added) {
      if (i >= 0) {
        if (!out[i].userIds.contains(delta.userId)) {
          out[i].userIds.add(delta.userId);
        }
      } else {
        out.add(ReactionEntity(
          emoji: delta.emoji,
          userIds: <String>[delta.userId],
        ));
      }
    } else {
      if (i >= 0) {
        out[i].userIds.remove(delta.userId);
        if (out[i].userIds.isEmpty) out.removeAt(i);
      }
    }
    out.sort((ReactionEntity a, ReactionEntity b) {
      final int c = b.count.compareTo(a.count);
      if (c != 0) return c;
      return a.emoji.compareTo(b.emoji);
    });
    return out;
  }

  Future<void> loadMore() async {
    final ChatState? current = state.valueOrNull;
    if (current == null) return;
    if (current.isLoadingMore || !current.hasMore) return;
    if (current.messages.isEmpty) return;

    state = AsyncData<ChatState>(current.copyWith(isLoadingMore: true));
    try {
      final GetMessages uc =
          await ref.read(getMessagesUseCaseProvider.future);
      final List<MessageEntity> older = await uc.call(
        GetMessagesParams(
          conversationId: arg,
          before: current.messages.first.createdAt,
          limit: _pageSize,
        ),
      );
      final List<MessageEntity> merged = <MessageEntity>[
        ...older.reversed,
        ...current.messages,
      ];
      state = AsyncData<ChatState>(
        current.copyWith(
          messages: merged,
          isLoadingMore: false,
          hasMore: older.length == _pageSize,
        ),
      );
    } catch (e) {
      state = AsyncData<ChatState>(
        current.copyWith(isLoadingMore: false, error: e),
      );
    }
  }

  Future<void> sendMessage(
    String content, {
    String? replyToId,
  }) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) return;
    await _send(content: trimmed, replyToId: replyToId);
  }

  Future<void> sendAttachment(
    OutgoingAttachment attachment, {
    String? caption,
    String? replyToId,
  }) async {
    await _send(
      content: caption,
      attachment: attachment,
      replyToId: replyToId,
    );
  }

  Future<void> _send({
    String? content,
    OutgoingAttachment? attachment,
    String? replyToId,
    String? forwardedFromMessageId,
    String? forwardedFromSenderId,
  }) async {
    final ChatState? current = state.valueOrNull;
    if (current == null) return;
    try {
      final SendMessage uc =
          await ref.read(sendMessageUseCaseProvider.future);
      final MessageEntity sent = await uc.call(
        SendMessageParams(
          conversationId: arg,
          content: content,
          attachment: attachment,
          replyToId: replyToId,
          forwardedFromMessageId: forwardedFromMessageId,
          forwardedFromSenderId: forwardedFromSenderId,
        ),
      );
      final List<MessageEntity> next = List<MessageEntity>.of(current.messages);
      if (next.every((MessageEntity m) => m.id != sent.id)) {
        next.add(sent);
      }
      state = AsyncData<ChatState>(current.copyWith(messages: next));
    } catch (e) {
      state = AsyncData<ChatState>(current.copyWith(error: e));
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    final ChatState? current = state.valueOrNull;
    if (current == null) return;
    final ChatRepository repo =
        await ref.read(chatRepositoryProvider.future);
    await repo.editMessage(messageId: messageId, content: newContent);
    final int i = current.messages.indexWhere(
      (MessageEntity m) => m.id == messageId,
    );
    if (i < 0) return;
    final List<MessageEntity> next = List<MessageEntity>.of(current.messages);
    next[i] = next[i].copyWith(
      content: newContent.trim(),
      editedAt: DateTime.now(),
    );
    state = AsyncData<ChatState>(current.copyWith(messages: next));
  }

  Future<void> deleteMessage(String messageId,
      {required bool forAll}) async {
    final ChatState? current = state.valueOrNull;
    if (current == null) return;
    final ChatRepository repo =
        await ref.read(chatRepositoryProvider.future);
    if (forAll) {
      await repo.deleteForAll(messageId);
      final int i = current.messages.indexWhere(
        (MessageEntity m) => m.id == messageId,
      );
      if (i < 0) return;
      final List<MessageEntity> next = List<MessageEntity>.of(current.messages);
      next[i] = next[i].copyWith(
        content: null,
        deletedAt: DateTime.now(),
        clearEditedAt: true,
        clearAttachment: true,
        reactions: const <ReactionEntity>[],
      );
      state = AsyncData<ChatState>(current.copyWith(messages: next));
    } else {
      await repo.deleteForMe(messageId);
      final List<MessageEntity> next = current.messages
          .where((MessageEntity m) => m.id != messageId)
          .toList();
      state = AsyncData<ChatState>(current.copyWith(messages: next));
    }
  }

  Future<void> togglePin(String messageId) async {
    final ChatState? current = state.valueOrNull;
    if (current == null) return;
    final int i = current.messages.indexWhere(
      (MessageEntity m) => m.id == messageId,
    );
    if (i < 0) return;
    final bool nextPinned = !current.messages[i].isPinned;
    final ChatRepository repo =
        await ref.read(chatRepositoryProvider.future);
    await repo.setPin(messageId: messageId, pinned: nextPinned);
    final List<MessageEntity> next = List<MessageEntity>.of(current.messages);
    next[i] = next[i].copyWith(
      pinnedAt: nextPinned ? DateTime.now() : null,
      clearPinnedAt: !nextPinned,
    );
    state = AsyncData<ChatState>(current.copyWith(messages: next));
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final ChatRepository repo =
        await ref.read(chatRepositoryProvider.future);
    await repo.toggleReaction(messageId: messageId, emoji: emoji);
  }

  Future<void> forwardMessageToConversation({
    required MessageEntity message,
    required String targetConversationId,
  }) async {
    final SendMessage uc =
        await ref.read(sendMessageUseCaseProvider.future);
    OutgoingAttachment? attachment; // переслать вложение нельзя без re-upload —
    // в рамках Phase 1 пересылаем только текст; вложение помечаем в content.
    String? content = message.content;
    if (message.hasAttachment && (content == null || content.isEmpty)) {
      content = '[вложение: ${message.attachmentKind?.value ?? 'файл'}]';
    }
    await uc.call(SendMessageParams(
      conversationId: targetConversationId,
      content: content,
      attachment: attachment,
      forwardedFromMessageId: message.id,
      forwardedFromSenderId: message.senderId,
    ));
  }

  Future<void> markAsRead() async {
    final MarkAsRead uc = await ref.read(markAsReadUseCaseProvider.future);
    await uc.call(arg);
  }
}

final AsyncNotifierProviderFamily<ChatController, ChatState, String>
    chatControllerProvider =
    AsyncNotifierProvider.family<ChatController, ChatState, String>(
  ChatController.new,
);
