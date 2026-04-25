import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/local_database.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../data/datasources/chat_local_datasource.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
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
    // Realtime-подписка живёт, пока существует провайдер.
    final ObserveMessages observe =
        await ref.watch(observeMessagesUseCaseProvider.future);
    final stream = observe.call(conversationId);
    final sub = stream.listen(_onIncoming);
    ref.onDispose(sub.cancel);

    final GetMessages uc =
        await ref.watch(getMessagesUseCaseProvider.future);
    final List<MessageEntity> page = await uc.call(
      GetMessagesParams(conversationId: conversationId, limit: _pageSize),
    );
    // Сервер возвращает DESC, мы храним ASC.
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
      next[existing] = message;
    } else {
      next.add(message);
      next.sort((MessageEntity a, MessageEntity b) =>
          a.createdAt.compareTo(b.createdAt));
    }
    state = AsyncData<ChatState>(current.copyWith(messages: next));
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

  Future<void> sendMessage(String content) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) return;
    await _send(content: trimmed);
  }

  Future<void> sendAttachment(OutgoingAttachment attachment, {
    String? caption,
  }) async {
    await _send(content: caption, attachment: attachment);
  }

  Future<void> _send({String? content, OutgoingAttachment? attachment}) async {
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
        ),
      );
      // Оптимистично: вставим сразу (Realtime, вероятно, повторит — defensive).
      final List<MessageEntity> next = List<MessageEntity>.of(current.messages);
      if (next.every((MessageEntity m) => m.id != sent.id)) {
        next.add(sent);
      }
      state = AsyncData<ChatState>(current.copyWith(messages: next));
    } catch (e) {
      state = AsyncData<ChatState>(current.copyWith(error: e));
    }
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
