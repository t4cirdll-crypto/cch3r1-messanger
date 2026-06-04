import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/admin_entities.dart';
import '../providers/admin_providers.dart';

class AdminConversationsScreen extends ConsumerWidget {
  const AdminConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminConversation>> convs =
        ref.watch(adminConversationsProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
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
        data: (List<AdminConversation> list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                'Диалогов нет',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(adminConversationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext _, int i) {
                final AdminConversation c = list[i];
                final String members = c.members
                    .map((AdminConversationMember m) =>
                        '@${m.username ?? m.userId.substring(0, 6)}')
                    .join(', ');
                final String title = c.title ??
                    (c.kind == 'saved' ? 'Saved Messages' : members);
                return _ConversationTile(
                  conversation: c,
                  title: title,
                  members: members,
                  onTap: () => context.push('/admin/conversation/${c.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({
    required this.conversation,
    required this.title,
    required this.members,
    required this.onTap,
  });

  final AdminConversation conversation;
  final String title;
  final String members;
  final VoidCallback onTap;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _pressed = false;

  IconData get _kindIcon {
    switch (widget.conversation.kind) {
      case 'group':
        return Icons.group;
      case 'saved':
        return Icons.bookmark_outline;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AdminConversation c = widget.conversation;
    final String title = widget.title.isEmpty ? '(без названия)' : widget.title;

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1.0,
      duration: AppDurations.instant,
      curve: AppCurves.standard,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (bool value) =>
              setState(() => _pressed = value),
          borderRadius: AppRadius.lgAll,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            curve: AppCurves.standard,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: AppShadows.sm(theme.brightness),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppGradients.fromScheme(scheme),
                    borderRadius: AppRadius.mdAll,
                    boxShadow: AppShadows.glow(scheme.primary, opacity: 0.22),
                  ),
                  child: Icon(
                    _kindIcon,
                    color: scheme.onPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${c.kind} • ${c.members.length} member(s) • '
                        '${c.messageCount} msg • '
                        '${widget.members.isEmpty ? "—" : widget.members}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
