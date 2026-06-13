import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/glass_widgets.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../chat_list/domain/entities/conversation_entity.dart';
import '../../../chat_list/presentation/providers/chat_list_providers.dart';

/// Экран выбора диалога для пересылки. Возвращает выбранный
/// [ConversationEntity] через `context.pop(...)`.
class ForwardPickerScreen extends ConsumerWidget {
  const ForwardPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ConversationEntity>> conversations =
        ref.watch(chatListControllerProvider);

    return Scaffold(
      appBar: GlassmorphicAppBar(
        title: const Text(AppStrings.forwardTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(child: Text('$e')),
        data: (List<ConversationEntity> list) {
          if (list.isEmpty) {
            return const Center(child: Text(AppStrings.chatsEmpty));
          }
          final ThemeData theme = Theme.of(context);
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: list.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 1,
              indent: AppSpacing.xxl + AppSpacing.xxl,
              endIndent: AppSpacing.lg,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            itemBuilder: (BuildContext _, int i) {
              final ConversationEntity c = list[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                leading: _buildAvatar(context, c),
                title: Text(
                  c.effectiveTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _subtitleFor(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mdAll,
                ),
                onTap: () => context.pop(c),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, ConversationEntity c) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    const double size = 40;

    Widget ringed(Widget child, {List<BoxShadow>? shadow}) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: shadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    if (c.isSaved) {
      return ringed(
        DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.brand,
          ),
          child: Icon(Icons.bookmark, color: scheme.onPrimary, size: 20),
        ),
        shadow: AppShadows.glow(scheme.primary, opacity: 0.3),
      );
    }
    if (c.isGroup) {
      final String t = c.effectiveTitle;
      return ringed(
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.fromScheme(scheme),
          ),
          child: Center(
            child: Text(
              t.isEmpty ? '?' : t.substring(0, 1).toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }
    final ProfileEntity? peer = c.peer;
    return ringed(
      CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        backgroundImage: peer?.avatarUrl != null
            ? CachedNetworkImageProvider(peer!.avatarUrl!)
            : null,
        child: peer?.avatarUrl == null
            ? Text(
                (peer?.effectiveName ?? '?').isEmpty
                    ? '?'
                    : (peer?.effectiveName ?? '?')
                        .substring(0, 1)
                        .toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
  }

  String _subtitleFor(ConversationEntity c) {
    if (c.isSaved) return 'Заметки для себя';
    if (c.isGroup) return '${c.members.length} участник(ов)';
    return '@${c.peer?.username ?? ''}';
  }
}
