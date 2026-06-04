import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/chat_providers.dart';
import '../services/attachment_url_cache.dart';
import 'attachment_url_loader.dart';

/// Картинка-вложение. Обращается к signed URL приватного bucket.
class AttachmentImage extends ConsumerWidget {
  const AttachmentImage({
    super.key,
    required this.message,
    required this.maxWidth,
  });

  final MessageEntity message;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AttachmentUrlCache> cache =
        ref.watch(attachmentUrlCacheProvider);
    return cache.when(
      loading: () => _placeholder(context),
      error: (Object e, _) => _error(context),
      data: (AttachmentUrlCache c) => AttachmentUrlLoader(
        cache: c,
        path: message.attachmentPath!,
        builder: (BuildContext context, String url) =>
            _image(context, url),
        loading: _placeholder(context),
        error: _error(context),
      ),
    );
  }

  Widget _image(BuildContext context, String url) {
    final double aspect = (message.attachmentWidth != null &&
            message.attachmentHeight != null &&
            message.attachmentWidth! > 0 &&
            message.attachmentHeight! > 0)
        ? message.attachmentWidth! / message.attachmentHeight!
        : 1.6;

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _openFullscreen(context, url),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 360),
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
      height: 200,
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
        builder: (BuildContext c) => _FullscreenImage(url: url),
      ),
    );
  }
}

/// Полноэкранный просмотрщик с кнопкой «Скачать в галерею».
class _FullscreenImage extends StatefulWidget {
  const _FullscreenImage({required this.url});
  final String url;

  @override
  State<_FullscreenImage> createState() => _FullscreenImageState();
}

class _FullscreenImageState extends State<_FullscreenImage> {
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bool hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final bool granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          _snack('Нет разрешения на доступ к галерее');
          return;
        }
      }
      final file = await DefaultCacheManager().getSingleFile(widget.url);
      await Gal.putImage(file.path, album: 'cch3r1');
      _snack('Сохранено в галерею');
    } catch (e) {
      _snack('Не удалось сохранить: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: <Widget>[
          IconButton(
            tooltip: 'Сохранить в галерею',
            onPressed: _saving ? null : _save,
            icon: AnimatedSwitcher(
              duration: AppDurations.fast,
              switchInCurve: AppCurves.standard,
              switchOutCurve: AppCurves.standard,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download_outlined, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: CachedNetworkImage(imageUrl: widget.url),
            ),
          ),
        ),
      ),
    );
  }
}
