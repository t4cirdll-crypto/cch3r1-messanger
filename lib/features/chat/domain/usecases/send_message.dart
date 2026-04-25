import '../../../../core/usecases/usecase.dart';
import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class SendMessageParams {
  const SendMessageParams({
    required this.conversationId,
    this.content,
    this.attachment,
  });
  final String conversationId;
  final String? content;
  final OutgoingAttachment? attachment;
}

class SendMessage extends UseCase<MessageEntity, SendMessageParams> {
  const SendMessage(this._repo);
  final ChatRepository _repo;

  @override
  Future<MessageEntity> call(SendMessageParams params) {
    return _repo.sendMessage(
      conversationId: params.conversationId,
      content: params.content,
      attachment: params.attachment,
    );
  }
}
