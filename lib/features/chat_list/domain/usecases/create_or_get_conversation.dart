import '../../../../core/usecases/usecase.dart';
import '../entities/conversation_entity.dart';
import '../repositories/chat_list_repository.dart';

class CreateOrGetConversation
    extends UseCase<ConversationEntity, String> {
  const CreateOrGetConversation(this._repo);
  final ChatListRepository _repo;

  @override
  Future<ConversationEntity> call(String peerId) =>
      _repo.createOrGetConversation(peerId);
}
