import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
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

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!message.isDeleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickEmojis
                      .map((String e) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.of(context).pop();
                                onPickEmoji(e);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          if (!message.isDeleted) const Divider(height: 1),
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
                  color: Theme.of(context).colorScheme.error),
              title: Text(
                AppStrings.actionDeleteForAll,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () =>
                  Navigator.of(context).pop(MessageAction.deleteForAll),
            ),
        ],
      ),
    );
  }
}
