import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

    return GestureDetector(
      onTap: () => _openFullscreen(context, url),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 320),
        child: AspectRatio(
          aspectRatio: aspect.clamp(0.6, 2.4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (BuildContext c, _) => _placeholder(c),
              errorWidget: (BuildContext c, _, __) => _error(c),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        height: 180,
        width: maxWidth,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );

  Widget _error(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.errorContainer,
        height: 100,
        width: maxWidth,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, size: 32),
      );

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
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: CachedNetworkImage(imageUrl: url),
            ),
          ),
        ),
      ),
    );
  }
}
