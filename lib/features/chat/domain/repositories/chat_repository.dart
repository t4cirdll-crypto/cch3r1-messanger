import 'dart:io';
import 'dart:typed_data';

import '../entities/message_entity.dart';

/// Полезная нагрузка вложения, передаваемая через repository в storage.
class OutgoingAttachment {
  const OutgoingAttachment({
    required this.kind,
    required this.mime,
    required this.extension,
    this.bytes,
    this.file,
    this.name,
    this.size,
    this.durationMs,
    this.width,
    this.height,
  })  : assert(bytes != null || file != null,
            'Нужно передать bytes или file');

  final AttachmentKind kind;
  final String mime;
  final String extension; // без точки, напр. 'jpg', 'mp4'
  final Uint8List? bytes;
  final File? file;
  final String? name;
  final int? size;
  final int? durationMs;
  final int? width;
  final int? height;
}

abstract class ChatRepository {
  /// Последние [limit] сообщений диалога. Если [before] != null — возвращает
  /// страницу более старых сообщений.
  Future<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 30,
    DateTime? before,
  });

  Future<MessageEntity> sendMessage({
    required String conversationId,
    String? content,
    OutgoingAttachment? attachment,
  });

  /// Возвращает короткоживущий signed URL для приватного вложения.
  Future<String> getAttachmentSignedUrl(String storagePath);

  /// Отмечает все «чужие» непрочитанные сообщения в диалоге прочитанными.
  Future<void> markAsRead(String conversationId);

  /// Стрим новых/обновлённых сообщений конкретного диалога.
  Stream<MessageEntity> watchMessages(String conversationId);
}
