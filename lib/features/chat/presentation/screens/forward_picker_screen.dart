import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
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
      appBar: AppBar(
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
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (BuildContext _, int i) {
              final ConversationEntity c = list[i];
              return ListTile(
                leading: _buildAvatar(context, c),
                title: Text(c.effectiveTitle),
                subtitle: Text(
                  _subtitleFor(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    if (c.isSaved) {
      return CircleAvatar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.bookmark),
      );
    }
    if (c.isGroup) {
      final String t = c.effectiveTitle;
      return CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        child: Text(t.isEmpty ? '?' : t.substring(0, 1).toUpperCase()),
      );
    }
    final ProfileEntity? peer = c.peer;
    return CircleAvatar(
      backgroundImage: peer?.avatarUrl != null
          ? CachedNetworkImageProvider(peer!.avatarUrl!)
          : null,
      child: peer?.avatarUrl == null
          ? Text(
              (peer?.effectiveName ?? '?').isEmpty
                  ? '?'
                  : (peer?.effectiveName ?? '?').substring(0, 1).toUpperCase(),
            )
          : null,
    );
  }

  String _subtitleFor(ConversationEntity c) {
    if (c.isSaved) return 'Заметки для себя';
    if (c.isGroup) return '${c.members.length} участник(ов)';
    return '@${c.peer?.username ?? ''}';
  }
}
