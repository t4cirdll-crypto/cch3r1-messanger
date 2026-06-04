import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/services/notifications_listener.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/glass_widgets.dart';
import '../../../../services/connection_service.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/chat_list_providers.dart';
import '../widgets/chat_list_skeleton.dart';
import '../widgets/conversation_tile.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  Future<void> _openSaved(BuildContext context, WidgetRef ref) async {
    try {
      final ConversationEntity saved =
          await ref.read(chatListControllerProvider.notifier).openSaved();
      if (!context.mounted) return;
      context.push('/chat/${saved.id}', extra: saved);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.somethingWentWrong}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ConversationEntity>> state =
        ref.watch(chatListControllerProvider);
    final String? uid = ref.watch(currentUserIdProvider);
    final AsyncValue<bool> online = ref.watch(connectivityProvider);

    // Запускаем фоновый слушатель новых сообщений (локальные уведомления).
    ref.read(messageNotificationsListenerProvider).start();

    return Scaffold(
      appBar: GlassmorphicAppBar(
        title: const Text(AppStrings.chatsTitle),
        actions: <Widget>[
          IconButton(
            tooltip: 'Saved Messages',
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () => _openSaved(context, ref),
          ),
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
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm - AppSpacing.xxs,
                horizontal: AppSpacing.lg,
              ),
              child: Text(
                AppStrings.offlineMode,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
                    return const _ChatListEmpty();
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      indent: 76,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.4),
                    ),
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
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: AppSpacing.md),
                        Text('$err', textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.lg),
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
      floatingActionButton: _NewChatFab(
        onNewChat: () => context.push('/search'),
        onNewGroup: () => context.push('/group/new'),
      ),
    );
  }
}

/// FAB с двумя действиями: новый чат / новая группа.
class _NewChatFab extends StatelessWidget {
  const _NewChatFab({required this.onNewChat, required this.onNewGroup});

  final VoidCallback onNewChat;
  final VoidCallback onNewGroup;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: AppStrings.newChat,
      position: PopupMenuPosition.over,
      onSelected: (String value) {
        if (value == 'chat') onNewChat();
        if (value == 'group') onNewGroup();
      },
      itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'chat',
          child: ListTile(
            leading: Icon(Icons.person_add),
            title: Text('Новый чат'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'group',
          child: ListTile(
            leading: Icon(Icons.group_add),
            title: Text('Новая группа'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: IgnorePointer(
        child: FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(Icons.edit),
          label: const Text(AppStrings.newChat),
        ),
      ),
    );
  }
}

/// Красивый empty-state для пустого списка чатов.
class _ChatListEmpty extends StatelessWidget {
  const _ChatListEmpty();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        const SizedBox(height: 96),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.92, end: 1),
            duration: AppDurations.slow,
            curve: AppCurves.spring,
            builder: (BuildContext context, double scale, Widget? child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.fromScheme(cs),
                boxShadow: AppShadows.glow(cs.primary, opacity: 0.22),
              ),
              child: Icon(
                Icons.forum_outlined,
                size: 56,
                color: cs.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: Text(
            AppStrings.chatsEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl + AppSpacing.sm,
          ),
          child: Text(
            'Нажмите кнопку «Написать», чтобы начать новый чат или создать группу.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
