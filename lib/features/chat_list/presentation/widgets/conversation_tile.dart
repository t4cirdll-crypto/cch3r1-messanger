import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
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
    final ColorScheme cs = theme.colorScheme;
    final MessageEntity? last = conversation.lastMessage;
    final bool outgoing = last != null &&
        last.senderId == currentUserId &&
        !last.isDeleted &&
        !last.isExpired;
    final bool unread = conversation.unreadCount > 0;
    final bool accented = unread && !conversation.muted;
    final String? rank = conversation.peer?.rank?.trim();
    final String preview = _previewFor(last);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: <Widget>[
            _Avatar(conversation: conversation),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (conversation.isGroup) ...<Widget>[
                        Icon(Icons.group_outlined,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: Text(
                          conversation.effectiveTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (rank != null && rank.isNotEmpty) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        _RankBadge(rank: rank),
                      ],
                      if (conversation.muted) ...<Widget>[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(Icons.notifications_off_outlined,
                            size: 14, color: cs.onSurfaceVariant),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      if (outgoing) ...<Widget>[
                        Icon(
                          last.isRead ? Icons.done_all_rounded : Icons.check,
                          semanticLabel: last.isRead
                              ? AppStrings.messageRead
                              : AppStrings.messageDelivered,
                          size: 16,
                          color: last.isRead ? cs.primary : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: Text(
                          outgoing ? 'Вы: $preview' : preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: unread ? cs.onSurface : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  DateFormatter.conversationTimestamp(
                      last?.createdAt ?? conversation.updatedAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accented ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: accented ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (unread)
                  Semantics(
                    label:
                        'Непрочитанных сообщений: ${conversation.unreadCount}',
                    excludeSemantics: true,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 22),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: accented ? cs.primary : cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        conversation.unreadCount > 99
                            ? '99+'
                            : '${conversation.unreadCount}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accented ? cs.onPrimary : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _previewFor(MessageEntity? message) {
    if (message == null) return AppStrings.noMessagesYet;
    if (message.isDeleted) return AppStrings.messageDeleted;
    if (message.isExpired) return AppStrings.messageExpired;
    final String text = (message.content ?? '').trim();
    if (text.isNotEmpty) return text;
    return switch (message.attachmentKind) {
      AttachmentKind.image => 'Фото',
      AttachmentKind.video => 'Видео',
      AttachmentKind.voice => 'Голосовое сообщение',
      AttachmentKind.file => message.attachmentName ?? 'Файл',
      AttachmentKind.gif => 'GIF',
      null => AppStrings.noMessagesYet,
    };
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final String rank;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: rank.toUpperCase(),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 58),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: AppRadius.xsAll,
        ),
        child: Text(
          rank.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: cs.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.conversation});

  final ConversationEntity conversation;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    if (conversation.isSaved) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: cs.primaryContainer,
        child: Icon(Icons.bookmark_rounded, color: cs.onPrimaryContainer),
      );
    }
    final ProfileEntity? peer = conversation.peer;
    final String name = conversation.effectiveTitle.trim();
    return Stack(
      children: <Widget>[
        UserAvatar(
          radius: 26,
          initial: name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          avatarUrl: peer?.avatarUrl,
        ),
        if (conversation.isDm && (peer?.isOnline ?? false))
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF22A06B),
                shape: BoxShape.circle,
                border:
                    Border.all(color: cs.surfaceContainerLowest, width: 2.5),
              ),
            ),
          ),
      ],
    );
  }
}
