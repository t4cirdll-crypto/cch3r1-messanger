import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/entities/message_entity.dart';
import 'attachment_audio_player.dart';
import 'attachment_file_card.dart';
import 'attachment_image.dart';
import 'attachment_video.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showRead = false,
  });

  final MessageEntity message;
  final bool isMine;
  final bool showRead;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    final Color bg = isMine ? scheme.primary : scheme.surfaceContainerHighest;
    final Color fg = isMine ? scheme.onPrimary : scheme.onSurface;
    final BorderRadius radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMine ? 16 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 16),
    );

    final double maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: _padding(),
          decoration: BoxDecoration(color: bg, borderRadius: radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
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
                    style: theme.textTheme.bodyLarge?.copyWith(color: fg),
                  ),
                ),
              const SizedBox(height: 2),
              Padding(
                padding: _textPadding(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      DateFormatter.shortTime(message.createdAt),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: fg.withValues(alpha: 0.75)),
                    ),
                    if (isMine && showRead) ...<Widget>[
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
      ),
    );
  }

  EdgeInsets _padding() {
    // Если есть медиа-вложение — ужмём паддинг, чтобы картинка/видео
    // прилегало к краям пузыря.
    if (message.hasAttachment &&
        (message.attachmentKind == AttachmentKind.image ||
            message.attachmentKind == AttachmentKind.video)) {
      return const EdgeInsets.all(4);
    }
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
  }

  EdgeInsets _textPadding() {
    if (message.hasAttachment &&
        (message.attachmentKind == AttachmentKind.image ||
            message.attachmentKind == AttachmentKind.video)) {
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
    }
  }
}
