import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../data/admin_repository.dart';
import '../../domain/entities/admin_entities.dart';
import '../providers/admin_providers.dart';

class AdminMessagesScreen extends ConsumerWidget {
  const AdminMessagesScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
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
        error: (Object e, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Text(
              '$e',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.error,
              ),
            ),
          ),
        ),
        data: (List<AdminMessage> list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                'Сообщений нет',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext _, int i) {
              final AdminMessage m = list[i];
              final bool isDeleted = m.deletedAt != null;
              final String body = isDeleted
                  ? '[удалено]'
                  : (m.content ??
                      (m.attachmentKind != null
                          ? '[${m.attachmentKind}: ${m.attachmentName ?? ""}]'
                          : '[пусто]'));
              final String handle =
                  '@${m.senderUsername ?? m.senderId.substring(0, 6)}';
              return AnimatedContainer(
                duration: AppDurations.fast,
                curve: AppCurves.standard,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: AppShadows.sm(theme.brightness),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: AppRadius.mdAll,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.person_outline,
                          size: 20,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              handle,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              body,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDeleted
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                                fontStyle: isDeleted
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${m.createdAt.toLocal()}'
                              '${m.editedAt != null ? " • edited" : ""}'
                              '${m.expiresAt != null ? " • expires ${m.expiresAt!.toLocal()}" : ""}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: scheme.onSurfaceVariant,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.mdAll,
                        ),
                        onSelected: (String action) async {
                          if (action != 'delete') return;
                          final AdminRepository repo =
                              ref.read(adminRepositoryProvider);
                          try {
                            await repo.deleteMessage(m.id);
                            ref.invalidate(
                                adminMessagesProvider(conversationId));
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
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
