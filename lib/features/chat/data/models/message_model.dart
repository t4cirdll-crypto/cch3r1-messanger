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
    String? content,
    @Default(false) @JsonKey(name: 'is_read') bool isRead,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'attachment_path') String? attachmentPath,
    @JsonKey(name: 'attachment_kind') String? attachmentKind,
    @JsonKey(name: 'attachment_name') String? attachmentName,
    @JsonKey(name: 'attachment_mime') String? attachmentMime,
    @JsonKey(name: 'attachment_size') int? attachmentSize,
    @JsonKey(name: 'attachment_duration_ms') int? attachmentDurationMs,
    @JsonKey(name: 'attachment_width') int? attachmentWidth,
    @JsonKey(name: 'attachment_height') int? attachmentHeight,
  }) = _MessageModel;

  factory MessageModel.fromJson(Map<String, dynamic> json) =>
      _$MessageModelFromJson(json);

  factory MessageModel.fromDb(Map<String, Object?> row) => MessageModel(
        id: row['id']! as String,
        conversationId: row['conversation_id']! as String,
        senderId: row['sender_id']! as String,
        content: row['content'] as String?,
        isRead: ((row['is_read'] as int?) ?? 0) == 1,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
        attachmentPath: row['attachment_path'] as String?,
        attachmentKind: row['attachment_kind'] as String?,
        attachmentName: row['attachment_name'] as String?,
        attachmentMime: row['attachment_mime'] as String?,
        attachmentSize: (row['attachment_size'] as num?)?.toInt(),
        attachmentDurationMs: (row['attachment_duration_ms'] as num?)?.toInt(),
        attachmentWidth: (row['attachment_width'] as num?)?.toInt(),
        attachmentHeight: (row['attachment_height'] as num?)?.toInt(),
      );

  Map<String, Object?> toDb() => <String, Object?>{
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content,
        'is_read': isRead ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'attachment_path': attachmentPath,
        'attachment_kind': attachmentKind,
        'attachment_name': attachmentName,
        'attachment_mime': attachmentMime,
        'attachment_size': attachmentSize,
        'attachment_duration_ms': attachmentDurationMs,
        'attachment_width': attachmentWidth,
        'attachment_height': attachmentHeight,
      };

  MessageEntity toEntity() => MessageEntity(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        isRead: isRead,
        createdAt: createdAt,
        attachmentPath: attachmentPath,
        attachmentKind: AttachmentKind.fromString(attachmentKind),
        attachmentName: attachmentName,
        attachmentMime: attachmentMime,
        attachmentSize: attachmentSize,
        attachmentDurationMs: attachmentDurationMs,
        attachmentWidth: attachmentWidth,
        attachmentHeight: attachmentHeight,
      );
}
