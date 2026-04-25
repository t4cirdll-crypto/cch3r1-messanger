import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../services/attachment_picker.dart';

/// Кнопка-микрофон в инпут-баре. Удерживай для записи, отпусти для отправки,
/// смахни влево для отмены.
class VoiceRecorderButton extends StatefulWidget {
  const VoiceRecorderButton({
    super.key,
    required this.onRecorded,
    required this.onError,
    this.onStateChanged,
  });

  /// Вызывается, когда запись успешно завершена и подготовлено вложение.
  final Future<void> Function(OutgoingAttachment attachment) onRecorded;

  /// Вызывается при ошибке (нет разрешения, ошибка записи и т.д.).
  final void Function(String message) onError;

  /// Сообщает наружу, идёт ли запись (для отрисовки оверлея).
  final ValueChanged<VoiceRecorderState>? onStateChanged;

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class VoiceRecorderState {
  const VoiceRecorderState({
    required this.isRecording,
    required this.isCancelling,
    required this.elapsed,
  });

  final bool isRecording;
  final bool isCancelling;
  final Duration elapsed;
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _ticker;
  DateTime? _startedAt;
  String? _path;
  bool _recording = false;
  bool _cancelling = false;
  double _dragX = 0;

  static const double _cancelThreshold = 80;

  @override
  void dispose() {
    _ticker?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _emit() {
    final Duration elapsed = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);
    widget.onStateChanged?.call(VoiceRecorderState(
      isRecording: _recording,
      isCancelling: _cancelling,
      elapsed: elapsed,
    ));
  }

  Future<void> _start() async {
    if (_recording) return;
    final bool ok = await AttachmentPicker.ensureMicPermission();
    if (!ok) {
      widget.onError('Нет доступа к микрофону');
      return;
    }
    final Directory dir = await getTemporaryDirectory();
    final String path = p.join(
      dir.path,
      'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 44100,
          bitRate: 64000,
        ),
        path: path,
      );
    } catch (e) {
      widget.onError('Не удалось начать запись: $e');
      return;
    }
    setState(() {
      _path = path;
      _recording = true;
      _cancelling = false;
      _startedAt = DateTime.now();
      _dragX = 0;
    });
    _emit();
    _ticker = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _emit(),
    );
  }

  Future<void> _finish({required bool cancel}) async {
    _ticker?.cancel();
    _ticker = null;
    if (!_recording) return;
    String? out;
    try {
      out = await _recorder.stop();
    } catch (_) {
      out = null;
    }
    final DateTime? started = _startedAt;
    final String? path = out ?? _path;
    setState(() {
      _recording = false;
      _cancelling = false;
      _startedAt = null;
      _dragX = 0;
    });
    _emit();

    if (cancel) {
      if (path != null) {
        try {
          final File f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      return;
    }
    if (path == null) {
      widget.onError('Запись не сохранилась');
      return;
    }
    final File file = File(path);
    if (!await file.exists()) {
      widget.onError('Файл записи не найден');
      return;
    }
    final int size = await file.length();
    if (size > kMaxAttachmentBytes) {
      try {
        await file.delete();
      } catch (_) {}
      widget.onError('Голосовое больше 25 МБ');
      return;
    }
    final Duration duration = started == null
        ? Duration.zero
        : DateTime.now().difference(started);
    if (duration.inMilliseconds < 350) {
      try {
        await file.delete();
      } catch (_) {}
      widget.onError('Удерживайте кнопку для записи');
      return;
    }
    await widget.onRecorded(
      OutgoingAttachment(
        kind: AttachmentKind.voice,
        mime: 'audio/mp4',
        extension: 'm4a',
        file: file,
        name: p.basename(file.path),
        size: size,
        durationMs: duration.inMilliseconds,
      ),
    );
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    if (!_recording) return;
    final double dx = d.localOffsetFromOrigin.dx;
    final bool nextCancelling = dx < -_cancelThreshold;
    if (nextCancelling != _cancelling || dx != _dragX) {
      setState(() {
        _cancelling = nextCancelling;
        _dragX = dx;
      });
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (_) => _start(),
      onLongPressMoveUpdate: _onLongPressMove,
      onLongPressEnd: (_) => _finish(cancel: _cancelling),
      onLongPressCancel: () => _finish(cancel: true),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: _recording
              ? (_cancelling ? Colors.red : Theme.of(context).colorScheme.primary)
              : Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(10),
        child: Icon(
          _recording ? Icons.mic : Icons.mic_none,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}

/// Полоса оверлея над инпут-баром, пока идёт запись.
class VoiceRecorderOverlay extends StatelessWidget {
  const VoiceRecorderOverlay({super.key, required this.state});
  final VoiceRecorderState state;

  @override
  Widget build(BuildContext context) {
    if (!state.isRecording) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final String time = _formatDuration(state.elapsed);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: <Widget>[
          _RedDot(),
          const SizedBox(width: 10),
          Text(time, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(
            state.isCancelling
                ? 'Отпустите, чтобы отменить'
                : '← Смахните для отмены',
            style: theme.textTheme.bodySmall?.copyWith(
              color: state.isCancelling
                  ? Colors.red
                  : theme.colorScheme.onSurfaceVariant,
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

class _RedDot extends StatefulWidget {
  @override
  State<_RedDot> createState() => _RedDotState();
}

class _RedDotState extends State<_RedDot>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((Duration d) {
      final bool nextOn = (d.inMilliseconds ~/ 500) % 2 == 0;
      if (nextOn != _on && mounted) setState(() => _on = nextOn);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _on ? 1 : 0.3,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
