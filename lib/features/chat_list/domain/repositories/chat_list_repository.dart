import '../entities/conversation_entity.dart';

abstract class ChatListRepository {
  /// Список диалогов текущего пользователя (свежие — первыми).
  Future<List<ConversationEntity>> getConversations();

  /// Создаёт диалог (или возвращает существующий) между текущим
  /// пользователем и [peerId].
  Future<ConversationEntity> createOrGetConversation(String peerId);

  /// Стрим изменений `conversations` для текущего пользователя.
  Stream<void> watchConversationChanges();
}
