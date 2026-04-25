import 'package:flutter/foundation.dart';

import '../../../auth/domain/entities/profile_entity.dart';
import '../../../chat/domain/entities/message_entity.dart';

@immutable
class ConversationEntity {
  const ConversationEntity({
    required this.id,
    required this.peer,
    required this.updatedAt,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String id;
  final ProfileEntity peer;
  final MessageEntity? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  ConversationEntity copyWith({
    String? id,
    ProfileEntity? peer,
    MessageEntity? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      peer: peer ?? this.peer,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
