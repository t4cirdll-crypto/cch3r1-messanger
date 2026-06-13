import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/message_entity.dart';

class ReplyPreview extends StatelessWidget {
  const ReplyPreview({
    super.key,
    required this.message,
    required this.onCancel,
  });

  final MessageEntity message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String text = previewMessageText(message);
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.6),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius:
                  const BorderRadius.all(Radius.circular(AppRadius.xs)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  AppStrings.replyTo,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppStrings.cancel,
            icon: const Icon(Icons.close),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

String previewMessageText(MessageEntity m) {
  if (m.isDeleted) return AppStrings.messageDeleted;
  if ((m.content ?? '').trim().isNotEmpty) return m.content!.trim();
  if (m.attachmentKind != null) {
    switch (m.attachmentKind!) {
      case AttachmentKind.image:
        return '🖼 Изображение';
      case AttachmentKind.video:
        return '🎬 Видео';
      case AttachmentKind.voice:
        return '🎤 Голосовое сообщение';
      case AttachmentKind.file:
        return '📎 ${m.attachmentName ?? "Файл"}';
      case AttachmentKind.gif:
        return '🎞 GIF';
    }
  }
  return '';
}

class QuotedMessage extends StatelessWidget {
  const QuotedMessage({
    super.key,
    required this.message,
    required this.foreground,
    required this.barColor,
  });
  final MessageEntity message;
  final Color foreground;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: barColor, width: 3)),
        color: foreground.withValues(alpha: 0.08),
        borderRadius: AppRadius.xsAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            AppStrings.replyTo,
            style: theme.textTheme.labelSmall?.copyWith(
              color: barColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            previewMessageText(message),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
