import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/chat_providers.dart';
import '../services/attachment_url_cache.dart';
import 'attachment_url_loader.dart';

/// Превью-видео в пузыре. По тапу открывает полноэкранный плеер.
class AttachmentVideo extends ConsumerWidget {
  const AttachmentVideo({
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
      loading: () => _stub(context, isLoading: true),
      error: (Object _, __) => _stub(context, isError: true),
      data: (AttachmentUrlCache c) => AttachmentUrlLoader(
        cache: c,
        path: message.attachmentPath!,
        loading: _stub(context, isLoading: true),
        error: _stub(context, isError: true),
        builder: (BuildContext c, String url) => GestureDetector(
          onTap: () => _open(c, url),
          child: _stub(c, label: _durationLabel()),
        ),
      ),
    );
  }

  Widget _stub(
    BuildContext context, {
    bool isLoading = false,
    bool isError = false,
    String? label,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isReady = !isLoading && !isError;
    final double w = maxWidth.clamp(160, 320);
    return ClipRRect(
      borderRadius: AppRadius.mdAll,
      child: Container(
        width: w,
        height: w * 9 / 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF1A1A1F), Color(0xFF050507)],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            if (isLoading)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else if (isError)
              const Icon(Icons.error_outline, color: Colors.white, size: 36)
            else
              AnimatedScale(
                scale: 1,
                duration: AppDurations.normal,
                curve: AppCurves.spring,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.glow(scheme.primary, opacity: 0.45),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            if (label != null && isReady)
              Positioned(
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: AppRadius.xsAll,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _durationLabel() {
    final int? ms = message.attachmentDurationMs;
    if (ms == null || ms <= 0) return null;
    final int total = ms ~/ 1000;
    final int m = total ~/ 60;
    final int s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _open(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _VideoPlayerScreen(url: url),
      ),
    );
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  const _VideoPlayerScreen({required this.url});
  final String url;

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.url))
          ..initialize().then((_) {
            if (!mounted) return;
            setState(() => _ready = true);
            _controller!.play();
          }).catchError((Object err) {
            if (!mounted) return;
            setState(() => _error = err);
          });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(child: _body()),
      floatingActionButton: !_ready || _error != null
          ? null
          : FloatingActionButton(
              onPressed: () {
                final VideoPlayerController c = _controller!;
                setState(() {
                  c.value.isPlaying ? c.pause() : c.play();
                });
              },
              child: AnimatedSwitcher(
                duration: AppDurations.fast,
                switchInCurve: AppCurves.standard,
                switchOutCurve: AppCurves.standard,
                transitionBuilder: (Widget child, Animation<double> anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  _controller!.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  key: ValueKey<bool>(_controller!.value.isPlaying),
                ),
              ),
            ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return const Icon(Icons.error_outline,
          color: Colors.white, size: 48);
    }
    if (!_ready) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          VideoPlayer(_controller!),
          VideoProgressIndicator(
            _controller!,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.white12,
            ),
          ),
        ],
      ),
    );
  }
}
