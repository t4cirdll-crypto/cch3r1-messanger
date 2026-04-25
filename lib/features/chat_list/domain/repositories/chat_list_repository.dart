import '../entities/conversation_entity.dart';

abstract class ChatListRepository {
  /// Список диалогов текущего пользователя (свежие — первыми).
  Future<List<ConversationEntity>> getConversations();

  /// Создаёт DM (или возвращает существующий) между текущим
  /// пользователем и [peerId].
  Future<ConversationEntity> createOrGetDm(String peerId);

  /// Создаёт группу с указанным заголовком и участниками
  /// (создатель автоматически становится owner-ом).
  Future<ConversationEntity> createGroup({
    required String title,
    required List<String> memberIds,
  });

  /// Возвращает (или создаёт) диалог «Saved Messages» текущего пользователя.
  Future<ConversationEntity> createOrGetSaved();

  /// Управление участниками группы.
  Future<void> addMember({
    required String conversationId,
    required String userId,
    String role = 'member',
  });
  Future<void> removeMember({
    required String conversationId,
    required String userId,
  });
  Future<void> changeRole({
    required String conversationId,
    required String userId,
    required String role,
  });
  Future<void> setGroupTitle({
    required String conversationId,
    required String title,
  });
  Future<void> setGroupAvatar({
    required String conversationId,
    required String? path,
  });

  /// Покинуть диалог (для группы — выход, для Saved — удаление).
  Future<void> leaveConversation(String conversationId);

  /// Помечает все сообщения диалога прочитанными.
  Future<void> markRead(String conversationId);

  /// Стрим изменений `conversations`/`conversation_members`/`messages`.
  Stream<void> watchConversationChanges();
}
