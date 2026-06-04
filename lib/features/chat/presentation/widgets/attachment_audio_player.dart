import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/message_entity.dart';
import '../providers/chat_providers.dart';
import '../services/attachment_url_cache.dart';

/// Плеер голосовых сообщений: play/pause, прогресс, длительность.
class AttachmentAudioPlayer extends ConsumerStatefulWidget {
  const AttachmentAudioPlayer({
    super.key,
    required this.message,
    required this.foreground,
  });

  final MessageEntity message;
  final Color foreground;

  @override
  ConsumerState<AttachmentAudioPlayer> createState() =>
      _AttachmentAudioPlayerState();
}

class _AttachmentAudioPlayerState
    extends ConsumerState<AttachmentAudioPlayer> {
  AudioPlayer? _player;
  bool _loading = false;
  Object? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _ensurePlayer() async {
    if (_player != null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final AttachmentUrlCache cache =
          await ref.read(attachmentUrlCacheProvider.future);
      final String url = await cache.resolve(widget.message.attachmentPath!);
      final AudioPlayer p = AudioPlayer();
      await p.setUrl(url);
      _player = p;
      _duration = p.duration ??
          Duration(milliseconds: widget.message.attachmentDurationMs ?? 0);
      _posSub = p.positionStream.listen((Duration d) {
        if (mounted) setState(() => _position = d);
      });
      _stateSub = p.playerStateStream.listen((PlayerState s) {
        if (!mounted) return;
        if (s.processingState == ProcessingState.completed) {
          p.pause();
          p.seek(Duration.zero);
        }
        setState(() {});
      });
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    await _ensurePlayer();
    final AudioPlayer? p = _player;
    if (p == null) return;
    if (p.playing) {
      await p.pause();
    } else {
      if (p.processingState == ProcessingState.completed) {
        await p.seek(Duration.zero);
      }
      await p.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Duration total = _duration.inMilliseconds > 0
        ? _duration
        : Duration(milliseconds: widget.message.attachmentDurationMs ?? 0);
    final double progress = total.inMilliseconds == 0
        ? 0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final bool playing = _player?.playing ?? false;
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      width: 220,
      child: Row(
        children: <Widget>[
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _loading ? null : _toggle,
            icon: AnimatedSwitcher(
              duration: AppDurations.fast,
              switchInCurve: AppCurves.standard,
              switchOutCurve: AppCurves.standard,
              transitionBuilder: (Widget child, Animation<double> animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: _loading
                  ? SizedBox(
                      key: const ValueKey<String>('audio-loading'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.foreground,
                      ),
                    )
                  : Icon(
                      _error != null
                          ? Icons.error_outline
                          : (playing ? Icons.pause : Icons.play_arrow),
                      key: ValueKey<String>(
                        _error != null
                            ? 'audio-error'
                            : (playing ? 'audio-pause' : 'audio-play'),
                      ),
                      color: widget.foreground,
                    ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: AppRadius.xsAll,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: widget.foreground.withValues(alpha: 0.25),
                    color: widget.foreground,
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatDuration(
                      _position == Duration.zero ? total : _position),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: widget.foreground.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    final int total = d.inSeconds;
    final int m = total ~/ 60;
    final int s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
