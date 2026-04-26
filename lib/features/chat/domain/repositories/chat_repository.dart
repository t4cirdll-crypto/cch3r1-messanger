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
    this.remoteUrl,
  })  : assert(bytes != null || file != null || remoteUrl != null,
            'Нужно передать bytes, file или remoteUrl');

  final AttachmentKind kind;
  final String mime;
  final String extension;
  final Uint8List? bytes;
  final File? file;
  final String? name;
  final int? size;
  final int? durationMs;
  final int? width;
  final int? height;

  /// Если задан — вложение не загружается в Supabase Storage,
  /// а сохраняется как полный URL (например, GIF c Giphy CDN).
  final String? remoteUrl;
}

class ReactionDelta {
  const ReactionDelta({
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.added,
  });
  final String messageId;
  final String userId;
  final String emoji;
  final bool added;
}

abstract class ChatRepository {
  Future<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 30,
    DateTime? before,
  });

  Future<MessageEntity> sendMessage({
    required String conversationId,
    String? content,
    OutgoingAttachment? attachment,
    String? replyToId,
    String? forwardedFromMessageId,
    String? forwardedFromSenderId,
  });

  Future<void> editMessage({
    required String messageId,
    required String content,
  });

  /// Удаление «для всех»: только отправитель. Очищает контент/вложение и
  /// помечает `deleted_at`.
  Future<void> deleteForAll(String messageId);

  /// Удаление «для меня»: локально удаляем из кэша.
  Future<void> deleteForMe(String messageId);

  Future<void> setPin({required String messageId, required bool pinned});

  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  });

  Future<List<MessageEntity>> searchInConversation({
    required String conversationId,
    required String query,
  });

  Future<List<MessageEntity>> getPinnedMessages(String conversationId);

  /// Возвращает короткоживущий signed URL для приватного вложения.
  Future<String> getAttachmentSignedUrl(String storagePath);

  /// Отмечает все «чужие» непрочитанные сообщения в диалоге прочитанными.
  Future<void> markAsRead(String conversationId);

  /// Стрим новых/обновлённых сообщений конкретного диалога.
  Stream<MessageEntity> watchMessages(String conversationId);

  /// Стрим id сообщений, удалённых физически (например, sweep исчезающих).
  Stream<String> watchMessageDeletes(String conversationId);

  /// Триггерит серверный sweep исчезающих сообщений (физическое удаление
  /// записей с `expires_at <= now()`).
  Future<int> sweepExpiredMessages();

  /// Стрим изменений реакций (фильтр по диалогу делает клиент по message_id).
  Stream<ReactionDelta> watchReactions();
}
