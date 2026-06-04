import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../config/giphy_config.dart';
import '../../../../core/theme/app_tokens.dart';
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: TextField(
            controller: _query,
            autofocus: false,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Поиск GIF…',
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              border: const OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide(color: scheme.primary, width: 1.5),
              ),
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
                    padding: const EdgeInsets.all(AppSpacing.xxl),
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.lg,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
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

class _GifTile extends StatefulWidget {
  const _GifTile({required this.gif, required this.onTap});
  final GiphyGif gif;
  final VoidCallback onTap;

  @override
  State<_GifTile> createState() => _GifTileState();
}

class _GifTileState extends State<_GifTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Brightness brightness = Theme.of(context).brightness;
    return AnimatedScale(
      scale: _pressed ? 0.95 : 1,
      duration: AppDurations.instant,
      curve: AppCurves.standard,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.smAll,
          boxShadow: AppShadows.sm(brightness),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            borderRadius: AppRadius.smAll,
            child: ClipRRect(
              borderRadius: AppRadius.smAll,
              child: CachedNetworkImage(
                imageUrl: widget.gif.previewUrl,
                fit: BoxFit.cover,
                placeholder: (BuildContext c, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.fromScheme(scheme),
                  ),
                  child: const SizedBox.expand(),
                ),
                errorWidget: (BuildContext c, _, __) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
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
      padding: EdgeInsets.all(AppSpacing.xxl),
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
