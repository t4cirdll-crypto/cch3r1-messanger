import '../entities/message_entity.dart';

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
    required String content,
  });

  /// Отмечает все «чужие» непрочитанные сообщения в диалоге прочитанными.
  Future<void> markAsRead(String conversationId);

  /// Стрим новых/обновлённых сообщений конкретного диалога.
  Stream<MessageEntity> watchMessages(String conversationId);
}
