import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/message_entity.dart';
import '../providers/chat_providers.dart';
import '../services/attachment_url_cache.dart';

/// Карточка произвольного файла с иконкой/именем/размером и кнопкой
/// «Открыть» (загружает во временный каталог и открывает системным viewer-ом).
class AttachmentFileCard extends ConsumerStatefulWidget {
  const AttachmentFileCard({
    super.key,
    required this.message,
    required this.foreground,
  });

  final MessageEntity message;
  final Color foreground;

  @override
  ConsumerState<AttachmentFileCard> createState() =>
      _AttachmentFileCardState();
}

class _AttachmentFileCardState extends ConsumerState<AttachmentFileCard> {
  bool _busy = false;
  String? _error;

  Future<void> _open() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final AttachmentUrlCache cache =
          await ref.read(attachmentUrlCacheProvider.future);
      final String url =
          await cache.resolve(widget.message.attachmentPath!);
      final HttpClient http = HttpClient();
      final HttpClientRequest req = await http.getUrl(Uri.parse(url));
      final HttpClientResponse resp = await req.close();
      if (resp.statusCode >= 400) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final Directory dir = await getTemporaryDirectory();
      final String safeName = widget.message.attachmentName ??
          p.basename(widget.message.attachmentPath!);
      final File out = File(p.join(dir.path, safeName));
      final IOSink sink = out.openWrite();
      await resp.pipe(sink);
      final OpenResult res = await OpenFilex.open(out.path);
      if (res.type != ResultType.done && mounted) {
        setState(() => _error = res.message);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name =
        widget.message.attachmentName ?? 'Файл';
    final String? sizeLabel =
        _formatSize(widget.message.attachmentSize);
    return InkWell(
      onTap: _open,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: widget.foreground.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                _iconFor(widget.message.attachmentMime),
                color: widget.foreground,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sizeLabel != null || _error != null)
                    Text(
                      _error ?? sizeLabel!,
                      style: TextStyle(
                        color: widget.foreground.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _busy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.foreground,
                    ),
                  )
                : Icon(Icons.file_download_outlined,
                    color: widget.foreground),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(String? mime) {
    if (mime == null) return Icons.insert_drive_file_outlined;
    if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (mime.startsWith('video/')) return Icons.videocam_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.contains('zip') || mime.contains('rar') || mime.contains('7z')) {
      return Icons.folder_zip_outlined;
    }
    if (mime.contains('word') || mime.contains('msword')) {
      return Icons.description_outlined;
    }
    if (mime.contains('excel') || mime.contains('sheet')) {
      return Icons.table_chart_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  static String? _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return null;
    const List<String> units = <String>['Б', 'КБ', 'МБ', 'ГБ'];
    double v = bytes.toDouble();
    int u = 0;
    while (v >= 1024 && u < units.length - 1) {
      v /= 1024;
      u++;
    }
    return '${v.toStringAsFixed(v >= 10 || u == 0 ? 0 : 1)} ${units[u]}';
  }
}
