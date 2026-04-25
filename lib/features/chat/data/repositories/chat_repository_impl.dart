import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart' as app;
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_local_datasource.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required this.remote,
    required this.local,
    required this.client,
  });

  final ChatRemoteDataSource remote;
  final ChatLocalDataSource local;
  final SupabaseClient client;

  String get _uid {
    final User? u = client.auth.currentUser;
    if (u == null) throw const app.AuthException('Нет активной сессии');
    return u.id;
  }

  @override
  Future<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 30,
    DateTime? before,
  }) async {
    try {
      final List<MessageModel> remoteList = await remote.getMessages(
        conversationId,
        limit: limit,
        before: before,
      );
      // Кэшируем только первую страницу (последние сообщения).
      if (before == null) {
        await local.cacheAll(conversationId, remoteList);
      }
      return remoteList
          .map((MessageModel m) => m.toEntity())
          .toList();
    } catch (_) {
      if (before != null) return <MessageEntity>[];
      final List<MessageModel> cached = await local.getMessages(conversationId);
      return cached.map((MessageModel m) => m.toEntity()).toList();
    }
  }

  @override
  Future<MessageEntity> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final MessageModel msg = await remote.sendMessage(
      conversationId: conversationId,
      senderId: _uid,
      content: content,
    );
    await local.upsert(msg);
    return msg.toEntity();
  }

  @override
  Future<void> markAsRead(String conversationId) {
    return remote.markAsRead(
      conversationId: conversationId,
      currentUserId: _uid,
    );
  }

  @override
  Stream<MessageEntity> watchMessages(String conversationId) async* {
    await for (final MessageModel m in remote.watchMessages(conversationId)) {
      await local.upsert(m);
      yield m.toEntity();
    }
  }
}
