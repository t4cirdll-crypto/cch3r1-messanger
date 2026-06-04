import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/message_entity.dart';

/// GIF-вложение. `attachment_path` хранит полный URL Giphy CDN, поэтому
/// signed URL получать не нужно.
class AttachmentGif extends StatelessWidget {
  const AttachmentGif({
    super.key,
    required this.message,
    required this.maxWidth,
  });

  final MessageEntity message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final String? url = message.attachmentPath;
    if (url == null) return _error(context);

    final double aspect = (message.attachmentWidth != null &&
            message.attachmentHeight != null &&
            message.attachmentWidth! > 0 &&
            message.attachmentHeight! > 0)
        ? message.attachmentWidth! / message.attachmentHeight!
        : 1.4;

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _openFullscreen(context, url),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 320),
        child: AspectRatio(
          aspectRatio: aspect.clamp(0.6, 2.4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppRadius.smAll,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
              boxShadow: AppShadows.sm(Theme.of(context).brightness),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.smAll,
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (BuildContext c, _) => _placeholder(c),
                errorWidget: (BuildContext c, _, __) => _error(c),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      height: 180,
      width: maxWidth,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            scheme.surfaceContainerHighest,
            scheme.surfaceContainerHigh,
          ],
        ),
      ),
      child: SizedBox(
        width: AppSpacing.xxl,
        height: AppSpacing.xxl,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: scheme.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _error(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      height: 100,
      width: maxWidth,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.smAll,
      ),
      child: Icon(
        Icons.broken_image_outlined,
        size: AppSpacing.xxxl,
        color: scheme.onErrorContainer,
      ),
    );
  }

  void _openFullscreen(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext c) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: AppRadius.mdAll,
                  child: CachedNetworkImage(imageUrl: url),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
