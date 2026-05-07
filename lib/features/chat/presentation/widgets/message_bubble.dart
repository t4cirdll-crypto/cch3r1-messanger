import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/entities/message_entity.dart';
import 'attachment_audio_player.dart';
import 'attachment_file_card.dart';
import 'attachment_gif.dart';
import 'attachment_image.dart';
import 'attachment_video.dart';
import 'reply_preview.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUserId,
    this.showRead = false,
    this.highlight = false,
    this.onLongPress,
    this.onReactionTap,
  });

  final MessageEntity message;
  final bool isMine;
  final String? currentUserId;
  final bool showRead;
  final bool highlight;
  final VoidCallback? onLongPress;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    // Входящие сообщения окрашиваем в `secondaryContainer`, чтобы они
    // визуально отделялись от фона чата (в Material 3 `surface` и
    // `surfaceContainerHighest` выглядят почти одинаково в светлой теме —
    // bubble «сливался» с экраном).
    final Color bg = highlight
        ? scheme.tertiaryContainer
        : isMine
            ? scheme.primary
            : scheme.secondaryContainer;
    final Color fg = highlight
        ? scheme.onTertiaryContainer
        : isMine
            ? scheme.onPrimary
            : scheme.onSecondaryContainer;
    final BorderRadius radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMine ? 16 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 16),
    );

    final double maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: GestureDetector(
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  padding: _padding(),
                  decoration: BoxDecoration(color: bg, borderRadius: radius),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (message.isPinned)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.push_pin,
                                  size: 12, color: fg.withValues(alpha: 0.75)),
                              const SizedBox(width: 4),
                              Text(
                                AppStrings.messagePinned,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: fg.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (message.isForwarded)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.fast_forward,
                                  size: 14, color: fg.withValues(alpha: 0.75)),
                              const SizedBox(width: 4),
                              Text(
                                AppStrings.messageForwarded,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: fg.withValues(alpha: 0.75),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (message.replyTo != null)
                        QuotedMessage(
                          message: message.replyTo!,
                          foreground: fg,
                          barColor: isMine ? scheme.onPrimary : scheme.primary,
                        ),
                      if (message.isDeleted)
                        Padding(
                          padding: _textPadding(),
                          child: Text(
                            AppStrings.messageDeleted,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: fg.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else ...<Widget>[
                        if (message.hasAttachment)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _attachmentWidget(maxWidth, fg),
                          ),
                        if (message.hasAttachment && message.hasText)
                          const SizedBox(height: 6),
                        if (message.hasText)
                          Padding(
                            padding: _textPadding(),
                            child: Text(
                              message.content!,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(color: fg),
                            ),
                          ),
                      ],
                      const SizedBox(height: 2),
                      Padding(
                        padding: _textPadding(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (message.isEdited && !message.isDeleted) ...<Widget>[
                              Text(
                                AppStrings.messageEdited,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: fg.withValues(alpha: 0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              DateFormatter.shortTime(message.createdAt),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: fg.withValues(alpha: 0.75)),
                            ),
                            if (message.expiresAt != null &&
                                !message.isDeleted) ...<Widget>[
                              const SizedBox(width: 4),
                              _ExpiryBadge(
                                expiresAt: message.expiresAt!,
                                color: fg,
                              ),
                            ],
                            if (isMine && showRead && !message.isDeleted) ...<Widget>[
                              const SizedBox(width: 4),
                              Icon(
                                message.isRead ? Icons.done_all : Icons.check,
                                size: 16,
                                color: fg.withValues(alpha: 0.85),
                                semanticLabel: message.isRead
                                    ? AppStrings.messageRead
                                    : AppStrings.messageDelivered,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.hasReactions)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      alignment:
                          isMine ? WrapAlignment.end : WrapAlignment.start,
                      children: message.reactions
                          .map((ReactionEntity r) => _ReactionChip(
                                reaction: r,
                                mine: r.isMine(currentUserId),
                                onTap: onReactionTap == null
                                    ? null
                                    : () => onReactionTap!(r.emoji),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _isVisualMedia =>
      message.hasAttachment &&
      (message.attachmentKind == AttachmentKind.image ||
          message.attachmentKind == AttachmentKind.video ||
          message.attachmentKind == AttachmentKind.gif);

  EdgeInsets _padding() {
    if (_isVisualMedia) {
      return const EdgeInsets.all(4);
    }
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  EdgeInsets _textPadding() {
    if (_isVisualMedia) {
      return const EdgeInsets.symmetric(horizontal: 8, vertical: 2);
    }
    return EdgeInsets.zero;
  }

  Widget _attachmentWidget(double maxWidth, Color fg) {
    switch (message.attachmentKind!) {
      case AttachmentKind.image:
        return AttachmentImage(
          message: message,
          maxWidth: maxWidth - 8,
        );
      case AttachmentKind.video:
        return AttachmentVideo(
          message: message,
          maxWidth: maxWidth - 8,
        );
      case AttachmentKind.voice:
        return AttachmentAudioPlayer(
          message: message,
          foreground: fg,
        );
      case AttachmentKind.file:
        return AttachmentFileCard(
          message: message,
          foreground: fg,
        );
      case AttachmentKind.gif:
        return AttachmentGif(
          message: message,
          maxWidth: maxWidth - 8,
        );
    }
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.reaction,
    required this.mine,
    this.onTap,
  });

  final ReactionEntity reaction;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color bg = mine ? cs.primaryContainer : cs.surfaceContainerHigh;
    final Color fg = mine ? cs.onPrimaryContainer : cs.onSurface;
    return Material(
      color: bg,
      shape: StadiumBorder(
        side: BorderSide(
          color: mine ? cs.primary : cs.outlineVariant,
          width: mine ? 1.2 : 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(reaction.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '${reaction.count}',
                style: theme.textTheme.labelSmall?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Бейдж с обратным отсчётом для self-destruct сообщений.
class _ExpiryBadge extends StatefulWidget {
  const _ExpiryBadge({required this.expiresAt, required this.color});

  final DateTime expiresAt;
  final Color color;

  @override
  State<_ExpiryBadge> createState() => _ExpiryBadgeState();
}

class _ExpiryBadgeState extends State<_ExpiryBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    if (d.isNegative || d == Duration.zero) return '0с';
    if (d.inSeconds < 60) return '${d.inSeconds}с';
    if (d.inMinutes < 60) return '${d.inMinutes}м';
    if (d.inHours < 24) return '${d.inHours}ч';
    return '${d.inDays}д';
  }

  @override
  Widget build(BuildContext context) {
    final Duration left = widget.expiresAt.difference(DateTime.now());
    final TextStyle? base = Theme.of(context).textTheme.bodySmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.timer_outlined,
          size: 14,
          color: widget.color.withValues(alpha: 0.75),
        ),
        const SizedBox(width: 2),
        Text(
          _format(left),
          style: base?.copyWith(color: widget.color.withValues(alpha: 0.75)),
        ),
      ],
    );
  }
}
