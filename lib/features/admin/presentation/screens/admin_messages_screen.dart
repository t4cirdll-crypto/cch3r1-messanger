import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/admin_repository.dart';
import '../../domain/entities/admin_entities.dart';
import '../providers/admin_providers.dart';

class AdminMessagesScreen extends ConsumerWidget {
  const AdminMessagesScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminMessage>> msgs =
        ref.watch(adminMessagesProvider(conversationId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сообщения (read-only)'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(adminMessagesProvider(conversationId)),
          ),
        ],
      ),
      body: msgs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('$e')),
        data: (List<AdminMessage> list) {
          if (list.isEmpty) {
            return const Center(child: Text('Сообщений нет'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (BuildContext _, int i) {
              final AdminMessage m = list[i];
              final String body = m.deletedAt != null
                  ? '[удалено]'
                  : (m.content ??
                      (m.attachmentKind != null
                          ? '[${m.attachmentKind}: ${m.attachmentName ?? ""}]'
                          : '[пусто]'));
              return ListTile(
                title: Text(
                  '@${m.senderUsername ?? m.senderId.substring(0, 6)}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(body),
                    Text(
                      '${m.createdAt.toLocal()}'
                      '${m.editedAt != null ? " • edited" : ""}'
                      '${m.expiresAt != null ? " • expires ${m.expiresAt!.toLocal()}" : ""}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (String action) async {
                    if (action != 'delete') return;
                    final AdminRepository repo =
                        ref.read(adminRepositoryProvider);
                    try {
                      await repo.deleteMessage(m.id);
                      ref.invalidate(adminMessagesProvider(conversationId));
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка: $e')),
                        );
                      }
                    }
                  },
                  itemBuilder: (BuildContext _) =>
                      const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Удалить сообщение'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
