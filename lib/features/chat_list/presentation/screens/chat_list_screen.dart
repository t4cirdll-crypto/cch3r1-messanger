import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../services/connection_service.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/chat_list_providers.dart';
import '../widgets/chat_list_skeleton.dart';
import '../widgets/conversation_tile.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ConversationEntity>> state =
        ref.watch(chatListControllerProvider);
    final String? uid = ref.watch(currentUserIdProvider);
    final AsyncValue<bool> online = ref.watch(connectivityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.chatsTitle),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.profileTitle,
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (online.valueOrNull == false)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Text(
                AppStrings.offlineMode,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(chatListControllerProvider.notifier).refresh(),
              child: state.when(
                data: (List<ConversationEntity> list) {
                  if (list.isEmpty) {
                    return ListView(
                      children: const <Widget>[
                        SizedBox(height: 120),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            AppStrings.chatsEmpty,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 76),
                    itemBuilder: (BuildContext ctx, int i) {
                      final ConversationEntity c = list[i];
                      return ConversationTile(
                        conversation: c,
                        currentUserId: uid,
                        onTap: () => context.push(
                          '/chat/${c.id}',
                          extra: c,
                        ),
                      );
                    },
                  );
                },
                loading: () => const ChatListSkeleton(),
                error: (Object err, StackTrace st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        Text('$err', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => ref
                              .read(chatListControllerProvider.notifier)
                              .refresh(),
                          child: const Text(AppStrings.retry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/search'),
        icon: const Icon(Icons.search),
        label: const Text(AppStrings.newChat),
      ),
    );
  }
}
