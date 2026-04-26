import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/admin_entities.dart';
import '../providers/admin_providers.dart';

class AdminConversationsScreen extends ConsumerWidget {
  const AdminConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminConversation>> convs =
        ref.watch(adminConversationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Диалоги'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminConversationsProvider),
          ),
        ],
      ),
      body: convs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('$e')),
        data: (List<AdminConversation> list) {
          if (list.isEmpty) {
            return const Center(child: Text('Диалогов нет'));
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(adminConversationsProvider),
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext _, int i) {
                final AdminConversation c = list[i];
                final String members = c.members
                    .map((AdminConversationMember m) =>
                        '@${m.username ?? m.userId.substring(0, 6)}')
                    .join(', ');
                final String title = c.title ??
                    (c.kind == 'saved' ? 'Saved Messages' : members);
                return ListTile(
                  leading: Icon(c.kind == 'group'
                      ? Icons.group
                      : c.kind == 'saved'
                          ? Icons.bookmark_outline
                          : Icons.chat_bubble_outline),
                  title: Text(title.isEmpty ? '(без названия)' : title),
                  subtitle: Text(
                    '${c.kind} • ${c.members.length} member(s) • '
                    '${c.messageCount} msg • ${members.isEmpty ? "—" : members}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push('/admin/conversation/${c.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
