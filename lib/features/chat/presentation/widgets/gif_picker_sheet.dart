import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../config/giphy_config.dart';
import '../../data/datasources/giphy_service.dart';

/// Bottom sheet с поиском по Giphy. Возвращает выбранный [GiphyGif] или null.
Future<GiphyGif?> showGifPicker(BuildContext context) {
  return showModalBottomSheet<GiphyGif>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (BuildContext c, ScrollController controller) =>
            _GifPickerView(scrollController: controller),
      );
    },
  );
}

class _GifPickerView extends StatefulWidget {
  const _GifPickerView({required this.scrollController});
  final ScrollController scrollController;

  @override
  State<_GifPickerView> createState() => _GifPickerViewState();
}

class _GifPickerViewState extends State<_GifPickerView> {
  final TextEditingController _query = TextEditingController();
  final GiphyService _service = GiphyService();
  Timer? _debounce;
  Future<List<GiphyGif>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _service.trending();
  }

  @override
  void dispose() {
    _query.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _future = value.trim().isEmpty
            ? _service.trending()
            : _service.search(value.trim());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!GiphyConfig.isEnabled) {
      return const _DisabledHint();
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _query,
            autofocus: false,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Поиск GIF…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: FutureBuilder<List<GiphyGif>>(
            future: _future,
            builder: (BuildContext c, AsyncSnapshot<List<GiphyGif>> snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Ошибка загрузки GIF: ${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final List<GiphyGif> items = snap.data ?? const <GiphyGif>[];
              if (items.isEmpty) {
                return const Center(child: Text('Ничего не найдено'));
              }
              return GridView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemCount: items.length,
                itemBuilder: (BuildContext c, int i) => _GifTile(
                  gif: items[i],
                  onTap: () => Navigator.of(context).pop(items[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GifTile extends StatelessWidget {
  const _GifTile({required this.gif, required this.onTap});
  final GiphyGif gif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: gif.previewUrl,
          fit: BoxFit.cover,
          placeholder: (BuildContext c, _) => Container(
            color:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          errorWidget: (BuildContext c, _, __) => const Icon(
            Icons.broken_image_outlined,
          ),
        ),
      ),
    );
  }
}

class _DisabledHint extends StatelessWidget {
  const _DisabledHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Text(
          'GIF-поиск недоступен: пересоберите APK с '
          '--dart-define=GIPHY_API_KEY=…',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
