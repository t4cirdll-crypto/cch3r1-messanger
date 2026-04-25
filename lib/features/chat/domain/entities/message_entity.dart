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

/// Реакция на сообщение (агрегат по эмодзи).
@immutable
class ReactionEntity {
  const ReactionEntity({
    required this.emoji,
    required this.userIds,
  });

  final String emoji;
  final List<String> userIds;

  int get count => userIds.length;
  bool isMine(String? userId) => userId != null && userIds.contains(userId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReactionEntity &&
          emoji == other.emoji &&
          listEquals(userIds, other.userIds));

  @override
  int get hashCode => Object.hash(emoji, Object.hashAll(userIds));
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
    this.editedAt,
    this.deletedAt,
    this.replyToId,
    this.replyTo,
    this.forwardedFromMessageId,
    this.forwardedFromSenderId,
    this.pinnedAt,
    this.reactions = const <ReactionEntity>[],
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

  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? replyToId;
  final MessageEntity? replyTo;
  final String? forwardedFromMessageId;
  final String? forwardedFromSenderId;
  final DateTime? pinnedAt;
  final List<ReactionEntity> reactions;

  final String? attachmentPath;
  final AttachmentKind? attachmentKind;
  final String? attachmentName;
  final String? attachmentMime;
  final int? attachmentSize;
  final int? attachmentDurationMs;
  final int? attachmentWidth;
  final int? attachmentHeight;

  bool get hasAttachment =>
      !isDeleted && attachmentPath != null && attachmentKind != null;
  bool get hasText => !isDeleted && (content ?? '').trim().isNotEmpty;
  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null;
  bool get isPinned => pinnedAt != null;
  bool get isForwarded => forwardedFromMessageId != null;
  bool get hasReactions => reactions.isNotEmpty;

  bool isMine(String? userId) => userId != null && senderId == userId;

  MessageEntity copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    bool? isRead,
    DateTime? createdAt,
    DateTime? editedAt,
    bool clearEditedAt = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? replyToId,
    bool clearReplyToId = false,
    MessageEntity? replyTo,
    bool clearReplyTo = false,
    String? forwardedFromMessageId,
    bool clearForwardedFromMessageId = false,
    String? forwardedFromSenderId,
    bool clearForwardedFromSenderId = false,
    DateTime? pinnedAt,
    bool clearPinnedAt = false,
    List<ReactionEntity>? reactions,
    String? attachmentPath,
    bool clearAttachment = false,
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
      editedAt: clearEditedAt ? null : (editedAt ?? this.editedAt),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      replyToId: clearReplyToId ? null : (replyToId ?? this.replyToId),
      replyTo: clearReplyTo ? null : (replyTo ?? this.replyTo),
      forwardedFromMessageId: clearForwardedFromMessageId
          ? null
          : (forwardedFromMessageId ?? this.forwardedFromMessageId),
      forwardedFromSenderId: clearForwardedFromSenderId
          ? null
          : (forwardedFromSenderId ?? this.forwardedFromSenderId),
      pinnedAt: clearPinnedAt ? null : (pinnedAt ?? this.pinnedAt),
      reactions: reactions ?? this.reactions,
      attachmentPath: clearAttachment
          ? null
          : (attachmentPath ?? this.attachmentPath),
      attachmentKind: clearAttachment
          ? null
          : (attachmentKind ?? this.attachmentKind),
      attachmentName: clearAttachment
          ? null
          : (attachmentName ?? this.attachmentName),
      attachmentMime: clearAttachment
          ? null
          : (attachmentMime ?? this.attachmentMime),
      attachmentSize:
          clearAttachment ? null : (attachmentSize ?? this.attachmentSize),
      attachmentDurationMs: clearAttachment
          ? null
          : (attachmentDurationMs ?? this.attachmentDurationMs),
      attachmentWidth:
          clearAttachment ? null : (attachmentWidth ?? this.attachmentWidth),
      attachmentHeight:
          clearAttachment ? null : (attachmentHeight ?? this.attachmentHeight),
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
          editedAt == other.editedAt &&
          deletedAt == other.deletedAt &&
          replyToId == other.replyToId &&
          forwardedFromMessageId == other.forwardedFromMessageId &&
          forwardedFromSenderId == other.forwardedFromSenderId &&
          pinnedAt == other.pinnedAt &&
          listEquals(reactions, other.reactions) &&
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
        editedAt,
        deletedAt,
        replyToId,
        forwardedFromMessageId,
        pinnedAt,
        Object.hashAll(reactions),
        attachmentPath,
        attachmentKind,
        Object.hash(
          attachmentName,
          attachmentMime,
          attachmentSize,
          attachmentDurationMs,
          attachmentWidth,
          attachmentHeight,
        ),
      );
}
