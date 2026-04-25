import 'package:flutter/foundation.dart';

@immutable
class MessageEntity {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  bool isMine(String? userId) => userId != null && senderId == userId;

  MessageEntity copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageEntity &&
          id == other.id &&
          conversationId == other.conversationId &&
          senderId == other.senderId &&
          content == other.content &&
          isRead == other.isRead &&
          createdAt == other.createdAt);

  @override
  int get hashCode =>
      Object.hash(id, conversationId, senderId, content, isRead, createdAt);
}
