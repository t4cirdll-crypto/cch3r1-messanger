import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../chat/domain/entities/message_entity.dart';
import '../../domain/entities/conversation_entity.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.onTap,
  });

  final ConversationEntity conversation;
  final String? currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ProfileEntity peer = conversation.peer;
    final MessageEntity? last = conversation.lastMessage;
    final String? lastContent = _previewFor(last);
    final DateTime time = last?.createdAt ?? conversation.updatedAt;
    final bool outgoing = currentUserId != null &&
        last != null &&
        last.senderId == currentUserId;

    return ListTile(
      onTap: onTap,
      leading: _Avatar(peer: peer),
      title: Text(
        peer.effectiveName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Text(
        lastContent == null
            ? '—'
            : outgoing
                ? 'Вы: $lastContent'
                : lastContent,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            DateFormatter.conversationTimestamp(time),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          if (conversation.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String? _previewFor(MessageEntity? m) {
    if (m == null) return null;
    final String text = (m.content ?? '').trim();
    if (text.isNotEmpty) return text;
    switch (m.attachmentKind) {
      case AttachmentKind.image:
        return '📷 Фото';
      case AttachmentKind.video:
        return '🎥 Видео';
      case AttachmentKind.voice:
        return '🎤 Голосовое сообщение';
      case AttachmentKind.file:
        return '📎 ${m.attachmentName ?? 'Файл'}';
      case null:
        return null;
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.peer});
  final ProfileEntity peer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String initial = (peer.effectiveName.isEmpty
            ? '?'
            : peer.effectiveName.substring(0, 1))
        .toUpperCase();

    return Stack(
      children: <Widget>[
        CircleAvatar(
          radius: 26,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          backgroundImage: peer.avatarUrl != null
              ? CachedNetworkImageProvider(peer.avatarUrl!)
              : null,
          child: peer.avatarUrl == null ? Text(initial) : null,
        ),
        if (peer.isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
