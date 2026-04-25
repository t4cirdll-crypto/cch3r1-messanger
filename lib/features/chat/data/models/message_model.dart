import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/message_entity.dart';

part 'message_model.freezed.dart';
part 'message_model.g.dart';

@freezed
class MessageModel with _$MessageModel {
  const MessageModel._();

  const factory MessageModel({
    required String id,
    @JsonKey(name: 'conversation_id') required String conversationId,
    @JsonKey(name: 'sender_id') required String senderId,
    required String content,
    @Default(false) @JsonKey(name: 'is_read') bool isRead,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _MessageModel;

  factory MessageModel.fromJson(Map<String, dynamic> json) =>
      _$MessageModelFromJson(json);

  factory MessageModel.fromDb(Map<String, Object?> row) => MessageModel(
        id: row['id']! as String,
        conversationId: row['conversation_id']! as String,
        senderId: row['sender_id']! as String,
        content: row['content']! as String,
        isRead: ((row['is_read'] as int?) ?? 0) == 1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      );

  Map<String, Object?> toDb() => <String, Object?>{
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'is_read': isRead ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  MessageEntity toEntity() => MessageEntity(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        isRead: isRead,
        createdAt: createdAt,
      );
}
