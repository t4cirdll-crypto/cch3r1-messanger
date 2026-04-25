import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../config/giphy_config.dart';

class GiphyGif {
  const GiphyGif({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.fullUrl,
    required this.width,
    required this.height,
  });

  final String id;
  final String title;

  /// Маленькая GIF-превью (~200px) для сетки выбора.
  final String previewUrl;

  /// Полный GIF, который вставляется в сообщение.
  final String fullUrl;
  final int width;
  final int height;
}

class GiphyService {
  GiphyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<GiphyGif>> trending({int limit = 30, int offset = 0}) {
    return _request(<String, String>{
      'limit': '$limit',
      'offset': '$offset',
      'rating': 'pg-13',
    }, '/trending');
  }

  Future<List<GiphyGif>> search(
    String query, {
    int limit = 30,
    int offset = 0,
  }) {
    return _request(<String, String>{
      'q': query,
      'limit': '$limit',
      'offset': '$offset',
      'rating': 'pg-13',
      'lang': 'ru',
    }, '/search');
  }

  Future<List<GiphyGif>> _request(
    Map<String, String> params,
    String endpoint,
  ) async {
    if (!GiphyConfig.isEnabled) {
      throw const GiphyException('GIPHY_API_KEY не задан');
    }
    final Uri uri = Uri.parse('${GiphyConfig.baseUrl}$endpoint').replace(
      queryParameters: <String, String>{
        ...params,
        'api_key': GiphyConfig.apiKey,
      },
    );
    final http.Response r = await _client.get(uri);
    if (r.statusCode != 200) {
      throw GiphyException('Giphy ${r.statusCode}: ${r.body}');
    }
    final Map<String, dynamic> body =
        jsonDecode(r.body) as Map<String, dynamic>;
    final List<dynamic> data = (body['data'] as List<dynamic>?) ?? <dynamic>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(_parse)
        .whereType<GiphyGif>()
        .toList();
  }

  static GiphyGif? _parse(Map<String, dynamic> raw) {
    final String? id = raw['id'] as String?;
    final Map<String, dynamic>? images =
        raw['images'] as Map<String, dynamic>?;
    if (id == null || images == null) return null;
    final Map<String, dynamic>? preview =
        (images['fixed_width'] as Map<String, dynamic>?) ??
            (images['preview_gif'] as Map<String, dynamic>?);
    final Map<String, dynamic>? full =
        (images['original'] as Map<String, dynamic>?) ?? preview;
    if (preview == null || full == null) return null;
    final String? previewUrl = preview['url'] as String?;
    final String? fullUrl = full['url'] as String?;
    if (previewUrl == null || fullUrl == null) return null;
    return GiphyGif(
      id: id,
      title: (raw['title'] as String?) ?? '',
      previewUrl: previewUrl,
      fullUrl: fullUrl,
      width: int.tryParse((full['width'] as String?) ?? '') ?? 0,
      height: int.tryParse((full['height'] as String?) ?? '') ?? 0,
    );
  }
}

class GiphyException implements Exception {
  const GiphyException(this.message);
  final String message;

  @override
  String toString() => 'GiphyException: $message';
}
