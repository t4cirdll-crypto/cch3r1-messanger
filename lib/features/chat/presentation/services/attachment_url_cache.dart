import 'dart:async';

import '../../domain/repositories/chat_repository.dart';

/// Кэш signed URL для приватного bucket. Supabase сами URL живут 1 час,
/// мы перевыпускаем за 10 минут до истечения.
class AttachmentUrlCache {
  AttachmentUrlCache(this._repo);
  final ChatRepository _repo;

  static const Duration _ttl = Duration(minutes: 50);

  final Map<String, _Entry> _cache = <String, _Entry>{};
  final Map<String, Future<String>> _inflight = <String, Future<String>>{};

  Future<String> resolve(String storagePath) {
    final _Entry? entry = _cache[storagePath];
    if (entry != null && entry.expiresAt.isAfter(DateTime.now())) {
      return Future<String>.value(entry.url);
    }
    final Future<String>? pending = _inflight[storagePath];
    if (pending != null) return pending;

    final Future<String> future = _refresh(storagePath);
    _inflight[storagePath] = future;
    future.whenComplete(() => _inflight.remove(storagePath));
    return future;
  }

  Future<String> _refresh(String storagePath) async {
    final String url = await _repo.getAttachmentSignedUrl(storagePath);
    _cache[storagePath] = _Entry(url, DateTime.now().add(_ttl));
    return url;
  }

  void invalidate(String storagePath) => _cache.remove(storagePath);
}

class _Entry {
  const _Entry(this.url, this.expiresAt);
  final String url;
  final DateTime expiresAt;
}
