import 'package:flutter/foundation.dart';

/// Тип вложения сообщения.
enum AttachmentKind {
  image,
  video,
  file,
  voice;

  static AttachmentKind? fromString(String? raw) {
    switch (raw) {
      case 'image':
        return AttachmentKind.image;
      case 'video':
        return AttachmentKind.video;
      case 'file':
        return AttachmentKind.file;
      case 'voice':
        return AttachmentKind.voice;
      default:
        return null;
    }
  }

  String get value => name;
}

@immutable
class MessageEntity {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.createdAt,
    this.content,
    this.isRead = false,
    this.attachmentPath,
    this.attachmentKind,
    this.attachmentName,
    this.attachmentMime,
    this.attachmentSize,
    this.attachmentDurationMs,
    this.attachmentWidth,
    this.attachmentHeight,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final bool isRead;
  final DateTime createdAt;

  // Вложение (любой из четырёх kind-ов либо null).
  final String? attachmentPath;
  final AttachmentKind? attachmentKind;
  final String? attachmentName;
  final String? attachmentMime;
  final int? attachmentSize;
  final int? attachmentDurationMs;
  final int? attachmentWidth;
  final int? attachmentHeight;

  bool get hasAttachment => attachmentPath != null && attachmentKind != null;
  bool get hasText => (content ?? '').trim().isNotEmpty;

  bool isMine(String? userId) => userId != null && senderId == userId;

  MessageEntity copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    bool? isRead,
    DateTime? createdAt,
    String? attachmentPath,
    AttachmentKind? attachmentKind,
    String? attachmentName,
    String? attachmentMime,
    int? attachmentSize,
    int? attachmentDurationMs,
    int? attachmentWidth,
    int? attachmentHeight,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      attachmentKind: attachmentKind ?? this.attachmentKind,
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentMime: attachmentMime ?? this.attachmentMime,
      attachmentSize: attachmentSize ?? this.attachmentSize,
      attachmentDurationMs: attachmentDurationMs ?? this.attachmentDurationMs,
      attachmentWidth: attachmentWidth ?? this.attachmentWidth,
      attachmentHeight: attachmentHeight ?? this.attachmentHeight,
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
          createdAt == other.createdAt &&
          attachmentPath == other.attachmentPath &&
          attachmentKind == other.attachmentKind &&
          attachmentName == other.attachmentName &&
          attachmentMime == other.attachmentMime &&
          attachmentSize == other.attachmentSize &&
          attachmentDurationMs == other.attachmentDurationMs &&
          attachmentWidth == other.attachmentWidth &&
          attachmentHeight == other.attachmentHeight);

  @override
  int get hashCode => Object.hash(
        id,
        conversationId,
        senderId,
        content,
        isRead,
        createdAt,
        attachmentPath,
        attachmentKind,
        attachmentName,
        attachmentMime,
        Object.hash(
          attachmentSize,
          attachmentDurationMs,
          attachmentWidth,
          attachmentHeight,
        ),
      );
}
