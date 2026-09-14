import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/local_database.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../data/datasources/chat_list_local_datasource.dart';
import '../../data/datasources/chat_list_remote_datasource.dart';
import '../../data/repositories/chat_list_repository_impl.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/repositories/chat_list_repository.dart';
import '../../domain/usecases/create_or_get_conversation.dart';
import '../../domain/usecases/get_conversations.dart';

final Provider<ChatListRemoteDataSource> chatListRemoteDataSourceProvider =
    Provider<ChatListRemoteDataSource>(
  (Ref ref) => ChatListRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final FutureProvider<ChatListLocalDataSource> chatListLocalDataSourceProvider =
    FutureProvider<ChatListLocalDataSource>((Ref ref) async {
  final LocalDatabase db = await ref.watch(localDatabaseProvider);
  return ChatListLocalDataSource(db);
});

final FutureProvider<ChatListRepository> chatListRepositoryProvider =
    FutureProvider<ChatListRepository>((Ref ref) async {
  final ChatListLocalDataSource local =
      await ref.watch(chatListLocalDataSourceProvider.future);
  return ChatListRepositoryImpl(
    remote: ref.watch(chatListRemoteDataSourceProvider),
    local: local,
    client: ref.watch(supabaseClientProvider),
  );
});

final FutureProvider<GetConversations> getConversationsUseCaseProvider =
    FutureProvider<GetConversations>(
  (Ref ref) async =>
      GetConversations(await ref.watch(chatListRepositoryProvider.future)),
);

final FutureProvider<CreateOrGetConversation>
    createOrGetConversationUseCaseProvider =
    FutureProvider<CreateOrGetConversation>(
  (Ref ref) async => CreateOrGetConversation(
    await ref.watch(chatListRepositoryProvider.future),
  ),
);

class ChatListController
    extends AutoDisposeAsyncNotifier<List<ConversationEntity>> {
  Object? _lifecycle;
  String? _accountId;
  bool _built = false;
  bool _loadingInitial = false;
  bool _dirty = false;
  Timer? _debounce;
  Future<void>? _refreshTask;

  bool _isCurrent(Object lifecycle) =>
      identical(_lifecycle, lifecycle) &&
      ref.read(currentUserIdProvider) == _accountId;

  @override
  Future<List<ConversationEntity>> build() async {
    final String? accountId = ref.watch(currentUserIdProvider);
    final bool changedAccount = _built && _accountId != accountId;
    final Object lifecycle = Object();
    _lifecycle = lifecycle;
    _accountId = accountId;
    _built = true;
    _loadingInitial = true;
    _dirty = false;
    _refreshTask = null;
    _debounce?.cancel();
    _debounce = null;
    ref.onDispose(() {
      if (!identical(_lifecycle, lifecycle)) return;
      _lifecycle = null;
      _debounce?.cancel();
      _debounce = null;
      _refreshTask = null;
    });

    if (changedAccount) {
      state = const AsyncData<List<ConversationEntity>>([]);
      state = const AsyncLoading<List<ConversationEntity>>();
    }
    if (accountId == null) {
      _loadingInitial = false;
      return const <ConversationEntity>[];
    }

    try {
      final ChatListRepository repo =
          await ref.watch(chatListRepositoryProvider.future);
      if (!_isCurrent(lifecycle)) return const <ConversationEntity>[];
      final StreamSubscription<void> subscription = repo
          .watchConversationChanges()
          .listen(
            (_) => _scheduleRefresh(lifecycle),
            onError: (Object _, StackTrace __) => _scheduleRefresh(lifecycle),
          );
      ref.onDispose(subscription.cancel);
      final List<ConversationEntity> list = await repo.getConversations();
      if (!_isCurrent(lifecycle)) return const <ConversationEntity>[];
      _loadingInitial = false;
      if (_dirty) _scheduleRefresh(lifecycle);
      return list;
    } catch (_) {
      if (_isCurrent(lifecycle)) {
        _loadingInitial = false;
        if (_dirty) _scheduleRefresh(lifecycle);
      }
      rethrow;
    }
  }

  void _scheduleRefresh(Object lifecycle) {
    if (!_isCurrent(lifecycle)) return;
    _dirty = true;
    if (_loadingInitial || _refreshTask != null) return;
    _debounce ??= Timer(const Duration(milliseconds: 250), () {
      _debounce = null;
      if (_isCurrent(lifecycle)) unawaited(refresh());
    });
  }

  Future<void> refresh() {
    final Object? lifecycle = _lifecycle;
    if (lifecycle == null || _accountId == null || !_isCurrent(lifecycle)) {
      return Future<void>.value();
    }
    _debounce?.cancel();
    _debounce = null;
    if (_refreshTask != null) return _refreshTask!;
    _dirty = true;
    if (_loadingInitial) return _refreshAfterInitial(lifecycle);
    return _refreshTask = _drainRefreshes(lifecycle);
  }

  Future<void> _refreshAfterInitial(Object lifecycle) async {
    try {
      await future;
    } catch (_) {
      // Explicit retry should also recover from an initial load failure.
    }
    if (_isCurrent(lifecycle)) await refresh();
  }

  Future<void> _drainRefreshes(Object lifecycle) async {
    try {
      while (_isCurrent(lifecycle) && _dirty) {
        _dirty = false;
        final AsyncValue<List<ConversationEntity>> previous = state;
        state = const AsyncLoading<List<ConversationEntity>>()
            .copyWithPrevious(previous);
        try {
          final ChatListRepository repo =
              await ref.read(chatListRepositoryProvider.future);
          if (!_isCurrent(lifecycle)) return;
          final List<ConversationEntity> list = await repo.getConversations();
          if (!_isCurrent(lifecycle)) return;
          state = AsyncData<List<ConversationEntity>>(list);
        } catch (error, stackTrace) {
          if (!_isCurrent(lifecycle)) return;
          state = AsyncError<List<ConversationEntity>>(error, stackTrace)
              .copyWithPrevious(previous);
        }
        // An event during the request gets one trailing fetch, never a parallel one.
      }
    } finally {
      if (identical(_lifecycle, lifecycle)) _refreshTask = null;
    }
  }

  Future<T> _mutate<T>(Future<T> Function(ChatListRepository) action,
      {bool reload = true}) async {
    final Object? lifecycle = _lifecycle;
    if (lifecycle == null || _accountId == null || !_isCurrent(lifecycle)) {
      throw StateError('Нет активной сессии');
    }
    final link = ref.keepAlive();
    try {
      final ChatListRepository repo =
          await ref.read(chatListRepositoryProvider.future);
      if (!_isCurrent(lifecycle)) throw StateError('Сессия изменилась');
      final T result = await action(repo);
      if (!_isCurrent(lifecycle)) throw StateError('Сессия изменилась');
      if (reload) await refresh();
      if (!_isCurrent(lifecycle)) throw StateError('Сессия изменилась');
      return result;
    } finally {
      link.close();
    }
  }

  Future<ConversationEntity> createGroup({
    required String title,
    required List<String> memberIds,
  }) =>
      _mutate((repo) => repo.createGroup(title: title, memberIds: memberIds));

  Future<ConversationEntity> openSaved() =>
      _mutate((repo) => repo.createOrGetSaved());

  Future<void> markRead(String conversationId) =>
      _mutate((repo) => repo.markRead(conversationId), reload: false);

  Future<void> setSelfDestruct(
          {required String conversationId, required int seconds}) =>
      _mutate((repo) => repo.setSelfDestruct(
          conversationId: conversationId, seconds: seconds));

  Future<void> setMute(
          {required String conversationId, required DateTime? until}) =>
      _mutate(
          (repo) => repo.setMute(conversationId: conversationId, until: until));
}

final chatListControllerProvider = AsyncNotifierProvider.autoDispose<
    ChatListController, List<ConversationEntity>>(ChatListController.new);
