import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/local_database.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/usecases/usecase.dart';
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

/// Контроллер списка чатов + реактивный рефетч при Realtime-событиях.
class ChatListController
    extends AsyncNotifier<List<ConversationEntity>> {
  @override
  Future<List<ConversationEntity>> build() async {
    // Реалтайм-триггер: любое изменение — рефетч списка.
    ref.listen<AsyncValue<void>>(
      _chatListChangesProvider,
      (AsyncValue<void>? prev, AsyncValue<void> next) {
        if (next.hasValue) {
          refresh();
        }
      },
    );

    final GetConversations uc =
        await ref.watch(getConversationsUseCaseProvider.future);
    return uc.call(const NoParams());
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<ConversationEntity>>();
    state = await AsyncValue.guard(() async {
      final GetConversations uc =
          await ref.read(getConversationsUseCaseProvider.future);
      return uc.call(const NoParams());
    });
  }

  Future<ConversationEntity> createGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    final ChatListRepository repo =
        await ref.read(chatListRepositoryProvider.future);
    final ConversationEntity created = await repo.createGroup(
      title: title,
      memberIds: memberIds,
    );
    await refresh();
    return created;
  }

  Future<ConversationEntity> openSaved() async {
    final ChatListRepository repo =
        await ref.read(chatListRepositoryProvider.future);
    final ConversationEntity saved = await repo.createOrGetSaved();
    await refresh();
    return saved;
  }

  Future<void> markRead(String conversationId) async {
    final ChatListRepository repo =
        await ref.read(chatListRepositoryProvider.future);
    await repo.markRead(conversationId);
  }
}

final AsyncNotifierProvider<ChatListController, List<ConversationEntity>>
    chatListControllerProvider =
    AsyncNotifierProvider<ChatListController, List<ConversationEntity>>(
  ChatListController.new,
);

/// Стрим Realtime-изменений; авто-отписка через Riverpod.
final AutoDisposeStreamProvider<void> _chatListChangesProvider =
    StreamProvider.autoDispose<void>((Ref ref) async* {
  final ChatListRepository repo =
      await ref.watch(chatListRepositoryProvider.future);
  final Stream<void> stream = repo.watchConversationChanges();
  await for (final _ in stream) {
    yield null;
  }
});
