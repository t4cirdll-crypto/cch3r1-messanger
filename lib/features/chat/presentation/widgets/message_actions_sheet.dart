import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/message_entity.dart';

enum MessageAction {
  reply,
  edit,
  copy,
  forward,
  pin,
  unpin,
  deleteForMe,
  deleteForAll,
}

class MessageActionsSheet extends StatelessWidget {
  const MessageActionsSheet({
    super.key,
    required this.message,
    required this.isMine,
    required this.onPickEmoji,
  });

  final MessageEntity message;
  final bool isMine;
  final ValueChanged<String> onPickEmoji;

  static Future<MessageAction?> show(
    BuildContext context, {
    required MessageEntity message,
    required bool isMine,
    required ValueChanged<String> onPickEmoji,
  }) {
    return showModalBottomSheet<MessageAction>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext _) => MessageActionsSheet(
        message: message,
        isMine: isMine,
        onPickEmoji: onPickEmoji,
      ),
    );
  }

  static const List<String> _quickEmojis = <String>[
    '👍', '❤️', '😂', '😮', '😢', '🔥', '👏', '🙏',
  ];

  @override
  Widget build(BuildContext context) {
    final bool canEdit = isMine &&
        !message.isDeleted &&
        DateTime.now().difference(message.createdAt) <
            const Duration(hours: 48) &&
        (message.content ?? '').trim().isNotEmpty;
    final bool hasContent = !message.isDeleted &&
        (message.content ?? '').trim().isNotEmpty;
    final bool canDeleteForAll = isMine && !message.isDeleted;
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!message.isDeleted)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickEmojis
                      .map((String e) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            child: Material(
                              color: scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                              shape: const StadiumBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  onPickEmoji(e);
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.all(AppSpacing.sm),
                                  child: Text(
                                    e,
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          if (!message.isDeleted)
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text(AppStrings.actionReply),
            onTap: () => Navigator.of(context).pop(MessageAction.reply),
          ),
          if (canEdit)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(AppStrings.actionEdit),
              onTap: () => Navigator.of(context).pop(MessageAction.edit),
            ),
          if (hasContent)
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text(AppStrings.actionCopy),
              onTap: () => Navigator.of(context).pop(MessageAction.copy),
            ),
          if (!message.isDeleted)
            ListTile(
              leading: const Icon(Icons.forward_outlined),
              title: const Text(AppStrings.actionForward),
              onTap: () => Navigator.of(context).pop(MessageAction.forward),
            ),
          ListTile(
            leading: Icon(message.isPinned
                ? Icons.push_pin_outlined
                : Icons.push_pin),
            title: Text(message.isPinned
                ? AppStrings.actionUnpin
                : AppStrings.actionPin),
            onTap: () => Navigator.of(context).pop(
              message.isPinned ? MessageAction.unpin : MessageAction.pin,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text(AppStrings.actionDeleteForMe),
            onTap: () =>
                Navigator.of(context).pop(MessageAction.deleteForMe),
          ),
          if (canDeleteForAll)
            ListTile(
              leading: Icon(Icons.delete_forever_outlined,
                  color: scheme.error),
              title: Text(
                AppStrings.actionDeleteForAll,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () =>
                  Navigator.of(context).pop(MessageAction.deleteForAll),
            ),
        ],
      ),
    );
  }
}
