import '../../../../core/usecases/usecase.dart';
import '../entities/conversation_entity.dart';
import '../repositories/chat_list_repository.dart';

class GetConversations extends UseCase<List<ConversationEntity>, NoParams> {
  const GetConversations(this._repo);
  final ChatListRepository _repo;

  @override
  Future<List<ConversationEntity>> call(NoParams params) =>
      _repo.getConversations();
}
