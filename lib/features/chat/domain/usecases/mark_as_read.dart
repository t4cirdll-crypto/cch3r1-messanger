import '../../../../core/usecases/usecase.dart';
import '../repositories/chat_repository.dart';

class MarkAsRead extends UseCase<void, String> {
  const MarkAsRead(this._repo);
  final ChatRepository _repo;

  @override
  Future<void> call(String conversationId) => _repo.markAsRead(conversationId);
}
