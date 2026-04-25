import '../../../../core/usecases/usecase.dart';
import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class GetMessagesParams {
  const GetMessagesParams({
    required this.conversationId,
    this.before,
    this.limit = 30,
  });
  final String conversationId;
  final DateTime? before;
  final int limit;
}

class GetMessages extends UseCase<List<MessageEntity>, GetMessagesParams> {
  const GetMessages(this._repo);
  final ChatRepository _repo;

  @override
  Future<List<MessageEntity>> call(GetMessagesParams params) {
    return _repo.getMessages(
      params.conversationId,
      limit: params.limit,
      before: params.before,
    );
  }
}
