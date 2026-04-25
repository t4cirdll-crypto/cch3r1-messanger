import '../../../../core/usecases/usecase.dart';
import '../entities/message_entity.dart';
import '../repositories/chat_repository.dart';

class SendMessageParams {
  const SendMessageParams({
    required this.conversationId,
    this.content,
    this.attachment,
    this.replyToId,
    this.forwardedFromMessageId,
    this.forwardedFromSenderId,
  });
  final String conversationId;
  final String? content;
  final OutgoingAttachment? attachment;
  final String? replyToId;
  final String? forwardedFromMessageId;
  final String? forwardedFromSenderId;
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
      replyToId: params.replyToId,
      forwardedFromMessageId: params.forwardedFromMessageId,
      forwardedFromSenderId: params.forwardedFromSenderId,
    );
  }
}
