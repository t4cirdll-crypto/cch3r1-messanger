import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
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
    final bool outgoing =
        currentUserId != null && last != null && last.senderId == currentUserId;

    final bool unread = conversation.unreadCount > 0;
    final ColorScheme cs = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      leading: _Avatar(conversation: conversation),
      title: Row(
        children: <Widget>[
          if (conversation.isGroup)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Icon(Icons.group, size: 18, color: cs.primary),
            ),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    conversation.effectiveTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                if (!conversation.isGroup &&
                    conversation.peer?.rank != null &&
                    conversation.peer!.rank!.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Builder(
                    builder: (BuildContext ctx) {
                      final String r = conversation.peer!.rank!.toUpperCase();
                      final Color bg;
                      final Color border;
                      final Color text;
                      if (r == 'BOT' || r == 'БОТ') {
                        bg = Colors.purple.withValues(alpha: 0.15);
                        border = Colors.purple.withValues(alpha: 0.4);
                        text = Colors.purple;
                      } else if (r == 'ADMIN' || r == 'АДМИН') {
                        bg = Colors.red.withValues(alpha: 0.15);
                        border = Colors.red.withValues(alpha: 0.4);
                        text = Colors.red;
                      } else if (r == 'VIP') {
                        bg = Colors.amber.withValues(alpha: 0.15);
                        border = Colors.amber.withValues(alpha: 0.4);
                        text = Colors.amber.shade800;
                      } else {
                        bg = cs.primaryContainer;
                        border = cs.primary.withValues(alpha: 0.4);
                        text = cs.primary;
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs + 1, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: AppRadius.xsAll,
                          border: Border.all(color: border, width: 1),
                        ),
                        child: Text(
                          conversation.peer!.rank!.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: text,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          if (conversation.muted)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Icon(
                Icons.notifications_off,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Row(
          children: <Widget>[
            if (outgoing) ...[
              Icon(
                last.isRead ? Icons.done_all : Icons.check,
                size: 16,
                color: last.isRead ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.65),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
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
          ],
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
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: AppDurations.normal,
            switchInCurve: AppCurves.spring,
            switchOutCurve: AppCurves.standard,
            transitionBuilder: (Widget child, Animation<double> a) =>
                ScaleTransition(scale: a, child: child),
            child: unread
                ? UnconstrainedBox(
                    key: ValueKey<int>(conversation.unreadCount),
                    child: _UnreadBadge(
                      count: conversation.unreadCount,
                      muted: conversation.muted,
                    ),
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
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.fromScheme(theme.colorScheme),
          boxShadow: AppShadows.glow(
            theme.colorScheme.primary,
            opacity: 0.28,
          ),
        ),
        child: const Icon(Icons.bookmark, color: Colors.white, size: 24),
      );
    }
    if (conversation.isGroup) {
      return UserAvatar(
        radius: 26,
        initial: _initials(conversation.effectiveTitle),
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
                  color: theme.colorScheme.surface,
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
  const _UnreadBadge({required this.count, required this.muted});

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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm - 1, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.pill)),
        boxShadow: muted ? null : AppShadows.glow(cs.primary, opacity: 0.28),
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
