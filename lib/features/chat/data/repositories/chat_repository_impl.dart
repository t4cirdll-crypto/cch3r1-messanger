import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

  static const Uuid _uuid = Uuid();

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
    String? content,
    OutgoingAttachment? attachment,
  }) async {
    AttachmentUpload? uploaded;
    if (attachment != null) {
      // Сначала загружаем файл в storage по пути {conversationId}/{messageId}.{ext}.
      // messageId генерируем заранее, чтобы привязать имя файла к будущей записи.
      final String messageId = _uuid.v4();
      final String storagePath = await remote.uploadAttachment(
        conversationId: conversationId,
        messageId: messageId,
        extension: attachment.extension,
        mime: attachment.mime,
        bytes: attachment.bytes,
        file: attachment.file,
      );
      uploaded = AttachmentUpload(
        path: storagePath,
        kind: attachment.kind.value,
        name: attachment.name,
        mime: attachment.mime,
        size: attachment.size,
        durationMs: attachment.durationMs,
        width: attachment.width,
        height: attachment.height,
      );
    }

    final MessageModel msg = await remote.sendMessage(
      conversationId: conversationId,
      senderId: _uid,
      content: content,
      attachment: uploaded,
    );
    await local.upsert(msg);
    return msg.toEntity();
  }

  @override
  Future<String> getAttachmentSignedUrl(String storagePath) {
    return remote.createSignedUrl(storagePath);
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
