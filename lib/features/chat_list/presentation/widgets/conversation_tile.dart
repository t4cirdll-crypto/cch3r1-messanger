import 'package:flutter/material.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/user_avatar.dart';
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
    final MessageEntity? last = conversation.lastMessage;
    final String? lastContent = _previewFor(last);
    final DateTime time = last?.createdAt ?? conversation.updatedAt;
    final bool outgoing = currentUserId != null &&
        last != null &&
        last.senderId == currentUserId;

    final bool unread = conversation.unreadCount > 0;
    final ColorScheme cs = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      leading: _Avatar(conversation: conversation),
      title: Row(
        children: <Widget>[
          if (conversation.isGroup)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.group, size: 18, color: cs.primary),
            ),
          Expanded(
            child: Text(
              conversation.effectiveTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
          if (conversation.muted)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.notifications_off,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          lastContent == null
              ? '—'
              : outgoing
                  ? 'Вы: $lastContent'
                  : lastContent,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: unread ? cs.onSurface : cs.onSurfaceVariant,
            fontWeight: unread ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            DateFormatter.conversationTimestamp(time),
            style: theme.textTheme.bodySmall?.copyWith(
              color: unread ? cs.primary : cs.onSurfaceVariant,
              fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (Widget child, Animation<double> a) =>
                ScaleTransition(scale: a, child: child),
            child: unread
                ? _UnreadBadge(
                    key: ValueKey<int>(conversation.unreadCount),
                    count: conversation.unreadCount,
                    muted: conversation.muted,
                  )
                : const SizedBox(key: ValueKey<String>('empty'), height: 18),
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
      case AttachmentKind.gif:
        return '🎞 GIF';
      case null:
        return null;
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.conversation});
  final ConversationEntity conversation;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (conversation.isSaved) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.bookmark),
      );
    }
    if (conversation.isGroup) {
      return UserAvatar(
        radius: 26,
        initial: _initials(conversation.effectiveTitle),
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
      );
    }
    final ProfileEntity? peer = conversation.peer;
    final String initial = _initials(peer?.effectiveName ?? '?');

    return Stack(
      children: <Widget>[
        UserAvatar(
          radius: 26,
          initial: initial,
          avatarUrl: peer?.avatarUrl,
        ),
        if (peer?.isOnline ?? false)
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

  static String _initials(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({super.key, required this.count, required this.muted});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color bg = muted ? cs.outline : cs.primary;
    final Color fg = muted ? cs.onSurface : cs.onPrimary;
    final String label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: muted
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}
