import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../auth/data/models/profile_model.dart';
import '../../../chat/data/models/message_model.dart';
import '../../domain/entities/conversation_entity.dart';

part 'conversation_model.freezed.dart';
part 'conversation_model.g.dart';

@freezed
class ConversationModel with _$ConversationModel {
  const ConversationModel._();

  const factory ConversationModel({
    required String id,
    @JsonKey(name: 'user1_id') required String user1Id,
    @JsonKey(name: 'user2_id') required String user2Id,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'user1') ProfileModel? user1,
    @JsonKey(name: 'user2') ProfileModel? user2,
    @JsonKey(name: 'last_message') MessageModel? lastMessage,
    @Default(0) int unreadCount,
  }) = _ConversationModel;

  factory ConversationModel.fromJson(Map<String, dynamic> json) =>
      _$ConversationModelFromJson(json);

  /// Возвращает сущность, в которой peer — это оппонент относительно `currentUserId`.
  ConversationEntity toEntity(String currentUserId) {
    final ProfileModel? peer = currentUserId == user1Id ? user2 : user1;
    if (peer == null) {
      throw StateError('peer profile not loaded for conversation $id');
    }
    return ConversationEntity(
      id: id,
      peer: peer.toEntity(),
      lastMessage: lastMessage?.toEntity(),
      unreadCount: unreadCount,
      updatedAt: updatedAt,
    );
  }
}
