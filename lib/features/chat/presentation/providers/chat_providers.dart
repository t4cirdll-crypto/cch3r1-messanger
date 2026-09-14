import 'dart:async';

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
class ChatController extends AutoDisposeFamilyAsyncNotifier<ChatState, String> {
  static const int _pageSize = 30;

  Object? _lifecycle;
  // Сохраняется между rebuild, чтобы сразу очистить данные прошлого аккаунта.
  String? _currentUserId;

  /// Сообщения, прилетевшие через realtime до того, как `build()`
  /// успел вернуть начальную страницу. Без буфера такие события
  /// просто терялись (в `_onIncoming` `state.valueOrNull == null` →
  /// ранний return), и пользователь не видел свежие сообщения, пока
  /// не сделает refresh — баг #3 «Проблемы с получением сообщений».
  final List<MessageEntity> _pendingIncoming = <MessageEntity>[];
  bool _initialLoadComplete = false;

  bool _isCurrent(Object lifecycle) => identical(_lifecycle, lifecycle);

  bool _hasCurrentUser(Object lifecycle) {
    if (!_isCurrent(lifecycle)) return false;
    final String? userId = _currentUserId;
    return userId != null && ref.read(currentUserIdProvider) == userId;
  }

  bool _canUseLoadedState(Object lifecycle) =>
      _hasCurrentUser(lifecycle) && _initialLoadComplete;

  @override
  Future<ChatState> build(String conversationId) async {
    final String? userId = ref.watch(currentUserIdProvider);
    final String? previousUserId = _currentUserId;
    final bool changedAccount =
        previousUserId != null && previousUserId != userId;
    final Object lifecycle = Object();
    _lifecycle = lifecycle;
    _currentUserId = userId;
    _pendingIncoming.clear();
    _initialLoadComplete = false;
    ref.onDispose(() {
      if (!_isCurrent(lifecycle)) return;
      _lifecycle = null;
      _pendingIncoming.clear();
      _initialLoadComplete = false;
    });

    if (changedAccount) {
      // Сначала убираем previous AsyncValue, затем возвращаем экран в loading.
      state = const AsyncData<ChatState>(ChatState(hasMore: false));
      state = const AsyncLoading<ChatState>();
    }

    // При logout не запрашиваем и не сохраняем сообщения прошлого аккаунта.
    if (userId == null) return const ChatState(hasMore: false);

    // Захватываем зависимости до await, чтобы старый build не трогал
    // disposed Ref.
    final Future<ObserveMessages> observeFuture =
        ref.watch(observeMessagesUseCaseProvider.future);
    final Future<ChatRepository> repoFuture =
        ref.watch(chatRepositoryProvider.future);
    final Future<GetMessages> getMessagesFuture =
        ref.watch(getMessagesUseCaseProvider.future);

    final ObserveMessages observe = await observeFuture;
    if (!_hasCurrentUser(lifecycle)) return const ChatState();
    final stream = observe.call(conversationId);
    final sub = stream.listen(
      (MessageEntity message) => _onIncoming(message, lifecycle),
    );
    ref.onDispose(sub.cancel);

    final ChatRepository repo = await repoFuture;
    if (!_hasCurrentUser(lifecycle)) return const ChatState();
    final reactionSub =
        repo.watchReactions().listen(
      (ReactionDelta delta) => _onReactionDelta(delta, lifecycle),
    );
    ref.onDispose(reactionSub.cancel);

    // Подписка на физическое удаление сообщений (sweep исчезающих).
    final deleteSub = repo
        .watchMessageDeletes(conversationId)
        .listen((String id) => _onMessageDeleted(id, lifecycle));
    ref.onDispose(deleteSub.cancel);

    // Серверный sweep: тикаем каждые 15 секунд, пока чат открыт, чтобы
    // исчезающие сообщения удалялись без ожидания минутного pg_cron.
    final Timer expirySweepTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) {
        if (!_hasCurrentUser(lifecycle)) return;
        // ignore: discarded_futures
        repo.sweepExpiredMessages();
      },
    );
    ref.onDispose(expirySweepTimer.cancel);

    // UI-тик: раз в секунду пересобираем стейт, если есть истёкшие сообщения,
    // которых сервер ещё не успел удалить — клиент моментально скрывает их
    // через геттер isExpired.
    final Timer expiryUiTickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _maybeTickExpiry(lifecycle),
    );
    ref.onDispose(expiryUiTickTimer.cancel);

    final GetMessages uc = await getMessagesFuture;
    if (!_hasCurrentUser(lifecycle)) return const ChatState();
    final List<MessageEntity> page = await uc.call(
      GetMessagesParams(conversationId: conversationId, limit: _pageSize),
    );
    if (!_hasCurrentUser(lifecycle)) return const ChatState();
    final List<MessageEntity> sorted = page.reversed.toList();

    // Сливаем буфер realtime-сообщений, накопившийся пока шёл fetch первой
    // страницы. Иначе свежие сообщения, прилетевшие в этот зазор, исчезали.
    final List<MessageEntity> merged = List<MessageEntity>.of(sorted);
    for (final MessageEntity m in _pendingIncoming) {
      final int existing = merged.indexWhere(
        (MessageEntity x) => x.id == m.id,
      );
      if (existing >= 0) {
        merged[existing] = _mergeIncoming(merged[existing], m);
      } else {
        merged.add(m);
      }
    }
    _pendingIncoming.clear();
    _initialLoadComplete = true;
    merged.sort((MessageEntity a, MessageEntity b) =>
        a.createdAt.compareTo(b.createdAt));

    return ChatState(
      messages: merged,
      hasMore: page.length == _pageSize,
    );
  }

  /// При update-событии realtime-стрим может прислать `replyTo == null` /
  /// `reactions == []`, потому что репозиторий гидратирует только из
  /// локального кеша. Сохраняем уже посчитанные значения, чтобы баббл не
  /// «терял» reply-превью или реакции при редактировании текста.
  static MessageEntity _mergeIncoming(
    MessageEntity prev,
    MessageEntity incoming,
  ) {
    if (incoming.isDeleted) return incoming;
    return incoming.copyWith(
      replyTo: incoming.replyTo ?? prev.replyTo,
      reactions: incoming.reactions.isEmpty
          ? prev.reactions
          : incoming.reactions,
    );
  }

  void _onMessageDeleted(String id, Object lifecycle) {
    if (!_hasCurrentUser(lifecycle)) return;
    final ChatState? current = state.valueOrNull;
    if (current == null) return;
    final List<MessageEntity> next = current.messages
        .where((MessageEntity m) => m.id != id)
        .toList();
    if (next.length == current.messages.length) return;
    state = AsyncData<ChatState>(current.copyWith(messages: next));
  }

  void _maybeTickExpiry(Object lifecycle) {
    if (!_hasCurrentUser(lifecycle)) return;
    final ChatState? current = state.valueOrNull;
    if (current == null) return;
    final DateTime now = DateTime.now();
    final bool hasNearExpiry = current.messages.any((MessageEntity m) {
      final DateTime? exp = m.expiresAt;
      return exp != null && exp.isBefore(now.add(const Duration(seconds: 2)));
    });
    if (!hasNearExpiry) return;
    // Триггерим перестройку UI, чтобы isExpired-фильтр сработал.
    state = AsyncData<ChatState>(current.copyWith());
  }

  void _onIncoming(MessageEntity message, Object lifecycle) {
    if (!_hasCurrentUser(lifecycle)) return;
    final ChatState? current = state.valueOrNull;
    if (current == null || !_initialLoadComplete) {
      // Initial fetch ещё не завершился — буферизуем, чтобы потом смержить
      // в `build()`. Так свежие realtime-события не теряются между
      // подпиской и первой страницей.
      final int existing = _pendingIncoming.indexWhere(
        (MessageEntity m) => m.id == message.id,
      );
      if (existing >= 0) {
        _pendingIncoming[existing] =
            _mergeIncoming(_pendingIncoming[existing], message);
      } else {
        _pendingIncoming.add(message);
      }
      return;
    }
    final List<MessageEntity> next = List<MessageEntity>.of(current.messages);
    final int existing = next.indexWhere(
      (MessageEntity m) => m.id == message.id,
    );
    if (existing >= 0) {
      next[existing] = _mergeIncoming(next[existing], message);
    } else {
      next.add(message);
      next.sort((MessageEntity a, MessageEntity b) =>
          a.createdAt.compareTo(b.createdAt));
    }
    state = AsyncData<ChatState>(current.copyWith(messages: next));

    // Если прилетел/изменился pin — баннер должен это учесть.
    if (message.isPinned) {
      ref.invalidate(pinnedMessagesProvider(arg));
    }
  }

  void _onReactionDelta(ReactionDelta delta, Object lifecycle) {
    if (!_hasCurrentUser(lifecycle)) return;
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
    final List<ReactionEntity> out = List<ReactionEntity>.of(current.map(
        (ReactionEntity r) => ReactionEntity(
            emoji: r.emoji, userIds: List<String>.of(r.userIds))));
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

  static List<MessageEntity> _mergePages(
    Iterable<MessageEntity> older,
    Iterable<MessageEntity> current,
  ) {
    final Map<String, MessageEntity> byId = <String, MessageEntity>{};
    for (final MessageEntity message in older) {
      byId[message.id] = message;
    }
    for (final MessageEntity message in current) {
      final MessageEntity? previous = byId[message.id];
      byId[message.id] =
          previous == null ? message : _mergeIncoming(previous, message);
    }
    final List<MessageEntity> merged = byId.values.toList()
      ..sort((MessageEntity a, MessageEntity b) =>
          a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  Future<void> loadMore() async {
    final Object? lifecycle = _lifecycle;
    if (lifecycle == null || !_canUseLoadedState(lifecycle)) return;
    final ChatState? current = state.valueOrNull;
    if (current == null) return;
    if (current.isLoadingMore || !current.hasMore) return;
    if (current.messages.isEmpty) return;

    state = AsyncData<ChatState>(current.copyWith(isLoadingMore: true));
    try {
      final GetMessages uc = await ref.read(getMessagesUseCaseProvider.future);
      if (!_canUseLoadedState(lifecycle)) return;
      final List<MessageEntity> older = await uc.call(
        GetMessagesParams(
          conversationId: arg,
          before: current.messages.first.createdAt,
          limit: _pageSize,
        ),
      );
      if (!_hasCurrentUser(lifecycle)) return;
      final ChatState? latest = state.valueOrNull;
      if (latest == null) return;
      final List<MessageEntity> merged =
          _mergePages(older.reversed, latest.messages);
      state = AsyncData<ChatState>(
        latest.copyWith(
          messages: merged,
          isLoadingMore: false,
          hasMore: older.length == _pageSize,
        ),
      );
    } catch (e) {
      if (!_hasCurrentUser(lifecycle)) return;
      final ChatState? latest = state.valueOrNull;
      if (latest == null) return;
      state = AsyncData<ChatState>(
        latest.copyWith(isLoadingMore: false, error: e),
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
    final Object? lifecycle = _lifecycle;
    if (lifecycle == null ||
        !_canUseLoadedState(lifecycle) ||
        state.valueOrNull == null) {
      throw StateError('Чат ещё загружается. Повторите попытку.');
    }
    try {
      final SendMessage uc = await ref.read(sendMessageUseCaseProvider.future);
      if (!_canUseLoadedState(lifecycle)) return;
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
      if (!_hasCurrentUser(lifecycle)) return;
      final ChatState? latest = state.valueOrNull;
      if (latest == null) return;
      final List<MessageEntity> next = List<MessageEntity>.of(latest.messages);
      if (next.every((MessageEntity m) => m.id != sent.id)) {
        next.add(sent);
        next.sort((MessageEntity a, MessageEntity b) =>
            a.createdAt.compareTo(b.createdAt));
      }
      state = AsyncData<ChatState>(
        latest.copyWith(messages: next, clearError: true),
      );
    } catch (e) {
      // Ошибку текущего аккаунта не глотаем — UI вернёт текст в инпут.
      // Параллельно сохраняем последнюю ошибку в state для возможной баннер-
      // диагностики, но обязательно прокидываем дальше.
      if (!_hasCurrentUser(lifecycle)) return;
      final ChatState? latest = state.valueOrNull;
      if (latest != null) {
        state = AsyncData<ChatState>(latest.copyWith(error: e));
      }
      rethrow;
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    final Object? lifecycle = _lifecycle;
    if (lifecycle == null ||
        !_canUseLoadedState(lifecycle) ||
        state.valueOrNull == null) {
      return;
    }
    final ChatRepository repo = await ref.read(chatRepositoryProvider.future);
    if (!_canUseLoadedState(lifecycle)) return;
    await repo.editMessage(messageId: messageId, content: newContent);
    if (!_hasCurrentUser(lifecycle)) return;
    final ChatState? latest = state.valueOrNull;
    if (latest == null) return;
    final int i = latest.messages.indexWhere(
      (MessageEntity m) => m.id == messageId,
    );
    if (i < 0 || latest.messages[i].isDeleted) return;
    final List<MessageEntity> next = List<MessageEntity>.of(latest.messages);
    next[i] = next[i].copyWith(
      content: newContent.trim(),
      editedAt: DateTime.now(),
    );
    state = AsyncData<ChatState>(latest.copyWith(messages: next));
  }

  Future<void> deleteMessage(String messageId, {required bool forAll}) async {
    final Object? lifecycle = _lifecycle;
    if (lifecycle == null ||
        !_canUseLoadedState(lifecycle) ||
        state.valueOrNull == null) {
      return;
    }
    final ChatRepository repo = await ref.read(chatRepositoryProvider.future);
    if (!_canUseLoadedState(lifecycle)) return;
    if (forAll) {
      await repo.deleteForAll(messageId);
      if (!_hasCurrentUser(lifecycle)) return;
      final ChatState? latest = state.valueOrNull;
      if (latest == null) return;
      final int i = latest.messages.indexWhere(
        (MessageEntity m) => m.id == messageId,
      );
      if (i < 0) return;
      final List<MessageEntity> next = List<MessageEntity>.of(latest.messages);
      next[i] = next[i].copyWith(
        content: '',
        deletedAt: DateTime.now(),
        clearEditedAt: true,
        clearReplyToId: true,
        clearReplyTo: true,
        clearAttachment: true,
        reactions: const <ReactionEntity>[],
      );
      state = AsyncData<ChatState>(latest.copyWith(messages: next));
    } else {
      await repo.deleteForMe(messageId);
      if (!_hasCurrentUser(lifecycle)) return;
      final ChatState? latest = state.valueOrNull;
      if (latest == null) return;
      final List<MessageEntity> next = latest.messages
          .where((MessageEntity m) => m.id != messageId)
          .toList();
      state = AsyncData<ChatState>(latest.copyWith(messages: next));
    }
  }

  Future<void> togglePin(String messageId) async {
    final Object? lifecycle = _lifecycle;
    if (lifecycle == null || !_canUseLoadedState(lifecycle)) return;
    final ChatState? current = state.valueOrNull;
    if (current == null) return;
    final int i = current.messages.indexWhere(
      (MessageEntity m) => m.id == messageId,
    );
    if (i < 0) return;
    final bool nextPinned = !current.messages[i].isPinned;
    final ChatRepository repo = await ref.read(chatRepositoryProvider.future);
    if (!_canUseLoadedState(lifecycle)) return;
    await repo.setPin(messageId: messageId, pinned: nextPinned);
    if (!_hasCurrentUser(lifecycle)) return;
    final ChatState? latest = state.valueOrNull;
    if (latest == null) return;
    final int latestIndex = latest.messages.indexWhere(
      (MessageEntity m) => m.id == messageId,
    );
    if (latestIndex < 0) return;
    final List<MessageEntity> next = List<MessageEntity>.of(latest.messages);
    next[latestIndex] = next[latestIndex].copyWith(
      pinnedAt: nextPinned ? DateTime.now() : null,
      clearPinnedAt: !nextPinned,
    );
    state = AsyncData<ChatState>(latest.copyWith(messages: next));
    // Refetch the canonical pinned list — закреплённые сообщения могут
    // оказаться вне текущей страницы, поэтому баннер не должен полагаться
    // только на `state.messages`.
    ref.invalidate(pinnedMessagesProvider(arg));
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    final Object? lifecycle = _lifecycle;
    if (lifecycle == null || !_canUseLoadedState(lifecycle)) return;
    final ChatRepository repo = await ref.read(chatRepositoryProvider.future);
    if (!_canUseLoadedState(lifecycle)) return;
    await repo.toggleReaction(messageId: messageId, emoji: emoji);
  }

  Future<void> forwardMessageToConversation({
    required MessageEntity message,
    required String targetConversationId,
  }) async {
    final Object? lifecycle = _lifecycle;
    if (lifecycle == null || !_canUseLoadedState(lifecycle)) return;
    final SendMessage uc = await ref.read(sendMessageUseCaseProvider.future);
    if (!_canUseLoadedState(lifecycle)) return;
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
    final Object? lifecycle = _lifecycle;
    if (lifecycle == null || !_hasCurrentUser(lifecycle)) return;
    final MarkAsRead uc = await ref.read(markAsReadUseCaseProvider.future);
    if (!_hasCurrentUser(lifecycle)) return;
    await uc.call(arg);
  }
}

final chatControllerProvider =
    AsyncNotifierProvider.autoDispose.family<ChatController, ChatState, String>(
  ChatController.new,
);

/// Канонический список закреплённых сообщений диалога.
///
/// Не зависит от пагинации `chatControllerProvider` — закреплённое сообщение
/// может оказаться значительно старше первой страницы и в `state.messages`
/// его не будет. Поэтому тянем отдельным запросом через
/// `getPinnedMessages` и инвалидaция вызывается из `togglePin`.
final pinnedMessagesProvider =
    FutureProvider.autoDispose.family<List<MessageEntity>, String>(
  (Ref ref, String conversationId) async {
    final String? userId = ref.watch(currentUserIdProvider);
    if (userId == null) return <MessageEntity>[];
    var disposed = false;
    ref.onDispose(() => disposed = true);
    final ChatRepository repo = await ref.watch(chatRepositoryProvider.future);
    if (disposed || ref.read(currentUserIdProvider) != userId) {
      return <MessageEntity>[];
    }
    final List<MessageEntity> list =
        await repo.getPinnedMessages(conversationId);
    if (disposed || ref.read(currentUserIdProvider) != userId) {
      return <MessageEntity>[];
    }
    list.sort((MessageEntity a, MessageEntity b) =>
        (a.pinnedAt ?? a.createdAt).compareTo(b.pinnedAt ?? b.createdAt));
    return list;
  },
);
