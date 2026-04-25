import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/entities/message_entity.dart';

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

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                message.content,
                style: theme.textTheme.bodyLarge?.copyWith(color: fg),
              ),
              const SizedBox(height: 2),
              Row(
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
            ],
          ),
        ),
      ),
    );
  }
}
