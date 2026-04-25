import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message_model.dart';

class ChatRemoteDataSource {
  ChatRemoteDataSource(this._client);
  final SupabaseClient _client;

  static const String attachmentsBucket = 'chat-attachments';

  Future<List<MessageModel>> getMessages(
    String conversationId, {
    int limit = 30,
    DateTime? before,
  }) async {
    dynamic query = _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId);
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final List<dynamic> rows = await query
        .order('created_at', ascending: false)
        .limit(limit);
    return rows
        .cast<Map<String, dynamic>>()
        .map(MessageModel.fromJson)
        .toList();
  }

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String senderId,
    String? content,
    AttachmentUpload? attachment,
  }) async {
    final Map<String, dynamic> payload = <String, dynamic>{
      'conversation_id': conversationId,
      'sender_id': senderId,
      if ((content ?? '').trim().isNotEmpty) 'content': content!.trim(),
      if (attachment != null) ...<String, dynamic>{
        'attachment_path': attachment.path,
        'attachment_kind': attachment.kind,
        if (attachment.name != null) 'attachment_name': attachment.name,
        if (attachment.mime != null) 'attachment_mime': attachment.mime,
        if (attachment.size != null) 'attachment_size': attachment.size,
        if (attachment.durationMs != null)
          'attachment_duration_ms': attachment.durationMs,
        if (attachment.width != null) 'attachment_width': attachment.width,
        if (attachment.height != null) 'attachment_height': attachment.height,
      },
    };

    final Map<String, dynamic> inserted =
        await _client.from('messages').insert(payload).select().single();
    return MessageModel.fromJson(inserted);
  }

  /// Загружает файл во вложение чата. Возвращает storage-путь
  /// (`{conversationId}/{messageId}.{ext}`), который потом сохраняется в
  /// `messages.attachment_path`.
  Future<String> uploadAttachment({
    required String conversationId,
    required String messageId,
    required String extension,
    required String mime,
    Uint8List? bytes,
    File? file,
  }) async {
    assert(bytes != null || file != null,
        'Нужно передать bytes или file для загрузки');
    final String key =
        '$conversationId/$messageId${extension.startsWith('.') ? extension : '.$extension'}';
    final FileOptions options = FileOptions(
      contentType: mime,
      upsert: true,
    );
    if (bytes != null) {
      await _client.storage.from(attachmentsBucket).uploadBinary(
            key,
            bytes,
            fileOptions: options,
          );
    } else {
      await _client.storage.from(attachmentsBucket).upload(
            key,
            file!,
            fileOptions: options,
          );
    }
    return key;
  }

  /// Подписанный URL для приватного bucket. По умолчанию — на час.
  Future<String> createSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) {
    return _client.storage
        .from(attachmentsBucket)
        .createSignedUrl(storagePath, expiresInSeconds);
  }

  Future<void> markAsRead({
    required String conversationId,
    required String currentUserId,
  }) async {
    await _client
        .from('messages')
        .update(<String, dynamic>{'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', currentUserId)
        .eq('is_read', false);
  }

  /// Подписка на INSERT/UPDATE в `messages` конкретного диалога.
  Stream<MessageModel> watchMessages(String conversationId) {
    final StreamController<MessageModel> controller =
        StreamController<MessageModel>.broadcast();

    final RealtimeChannel channel = _client
        .channel('public:messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (PostgresChangePayload payload) {
            controller.add(MessageModel.fromJson(payload.newRecord));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (PostgresChangePayload payload) {
            controller.add(MessageModel.fromJson(payload.newRecord));
          },
        );
    channel.subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };

    return controller.stream;
  }
}

/// Параметры вложения, которые отправляются вместе с `sendMessage` после
/// успешной загрузки файла в storage.
class AttachmentUpload {
  const AttachmentUpload({
    required this.path,
    required this.kind,
    this.name,
    this.mime,
    this.size,
    this.durationMs,
    this.width,
    this.height,
  });

  final String path; // {conversationId}/{messageId}.{ext}
  final String kind; // 'image' | 'video' | 'file' | 'voice'
  final String? name;
  final String? mime;
  final int? size;
  final int? durationMs;
  final int? width;
  final int? height;
}
