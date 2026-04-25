import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class ObserveMessages {
  const ObserveMessages(this._repo);
  final ChatRepository _repo;

  Stream<MessageEntity> call(String conversationId) =>
      _repo.watchMessages(conversationId);
}
