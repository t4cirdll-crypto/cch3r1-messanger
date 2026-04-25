import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../auth/data/models/profile_model.dart';
import '../../../chat/data/models/message_model.dart';

part 'conversation_model.freezed.dart';
part 'conversation_model.g.dart';

/// Сырые поля строки `conversations` без агрегации участников/peer/unread.
/// Гидратация в `ConversationEntity` выполняется в репозитории.
@freezed
class ConversationModel with _$ConversationModel {
  const factory ConversationModel({
    required String id,
    @JsonKey(name: 'kind') required String kind,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @JsonKey(name: 'title') String? title,
    @JsonKey(name: 'avatar_path') String? avatarPath,
    @JsonKey(name: 'created_by') String? createdBy,
    @JsonKey(name: 'user1_id') String? user1Id,
    @JsonKey(name: 'user2_id') String? user2Id,
    @JsonKey(name: 'last_message') MessageModel? lastMessage,
  }) = _ConversationModel;

  factory ConversationModel.fromJson(Map<String, dynamic> json) =>
      _$ConversationModelFromJson(json);
}

/// Строка `conversation_members` с присоединённым profiles.
@freezed
class ConversationMemberModel with _$ConversationMemberModel {
  const factory ConversationMemberModel({
    @JsonKey(name: 'conversation_id') required String conversationId,
    @JsonKey(name: 'user_id') required String userId,
    @JsonKey(name: 'role') required String role,
    @JsonKey(name: 'joined_at') required DateTime joinedAt,
    @JsonKey(name: 'last_read_at') DateTime? lastReadAt,
    @JsonKey(name: 'muted_until') DateTime? mutedUntil,
    @JsonKey(name: 'profile') ProfileModel? profile,
  }) = _ConversationMemberModel;

  factory ConversationMemberModel.fromJson(Map<String, dynamic> json) =>
      _$ConversationMemberModelFromJson(json);
}
