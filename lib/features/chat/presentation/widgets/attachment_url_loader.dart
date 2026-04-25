import 'package:flutter/material.dart';

import '../services/attachment_url_cache.dart';

/// Хелпер: загружает signed URL из кэша и пересобирает дочерний widget,
/// когда URL готов.
class AttachmentUrlLoader extends StatefulWidget {
  const AttachmentUrlLoader({
    super.key,
    required this.cache,
    required this.path,
    required this.builder,
    required this.loading,
    required this.error,
  });

  final AttachmentUrlCache cache;
  final String path;
  final Widget Function(BuildContext context, String url) builder;
  final Widget loading;
  final Widget error;

  @override
  State<AttachmentUrlLoader> createState() => _AttachmentUrlLoaderState();
}

class _AttachmentUrlLoaderState extends State<AttachmentUrlLoader> {
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.cache.resolve(widget.path);
  }

  @override
  void didUpdateWidget(covariant AttachmentUrlLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _future = widget.cache.resolve(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<String> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return widget.loading;
        }
        if (snap.hasError || snap.data == null) {
          return widget.error;
        }
        return widget.builder(context, snap.data!);
      },
    );
  }
}
