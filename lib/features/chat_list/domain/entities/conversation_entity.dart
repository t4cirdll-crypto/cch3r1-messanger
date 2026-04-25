import 'package:flutter/foundation.dart';

import '../../../auth/domain/entities/profile_entity.dart';
import '../../../chat/domain/entities/message_entity.dart';

/// Тип диалога.
///   - `dm`     — личный чат двух пользователей.
///   - `group`  — групповой чат с произвольным числом участников.
///   - `saved`  — «избранное» (диалог с самим собой), создаётся автоматически.
enum ConversationKind {
  dm,
  group,
  saved;

  static ConversationKind fromString(String? value) {
    switch (value) {
      case 'group':
        return ConversationKind.group;
      case 'saved':
        return ConversationKind.saved;
      case 'dm':
      default:
        return ConversationKind.dm;
    }
  }

  String get value => switch (this) {
        ConversationKind.dm => 'dm',
        ConversationKind.group => 'group',
        ConversationKind.saved => 'saved',
      };
}

/// Роль участника.
enum MemberRole {
  owner,
  admin,
  member;

  static MemberRole fromString(String? value) {
    switch (value) {
      case 'owner':
        return MemberRole.owner;
      case 'admin':
        return MemberRole.admin;
      case 'member':
      default:
        return MemberRole.member;
    }
  }

  String get value => switch (this) {
        MemberRole.owner => 'owner',
        MemberRole.admin => 'admin',
        MemberRole.member => 'member',
      };
}

@immutable
class ConversationMember {
  const ConversationMember({
    required this.profile,
    required this.role,
    required this.joinedAt,
    this.lastReadAt,
    this.mutedUntil,
  });

  final ProfileEntity profile;
  final MemberRole role;
  final DateTime joinedAt;
  final DateTime? lastReadAt;
  final DateTime? mutedUntil;

  bool get isOwner => role == MemberRole.owner;
  bool get isAdmin => role == MemberRole.admin;
}

@immutable
class ConversationEntity {
  const ConversationEntity({
    required this.id,
    required this.kind,
    required this.updatedAt,
    required this.members,
    this.title,
    this.avatarPath,
    this.peer,
    this.lastMessage,
    this.unreadCount = 0,
    this.muted = false,
    this.selfDestructSeconds = 0,
  });

  final String id;
  final ConversationKind kind;
  final DateTime updatedAt;
  final List<ConversationMember> members;
  final String? title;
  final String? avatarPath;

  /// Для DM — другой участник. Для группы / Saved — null.
  final ProfileEntity? peer;
  final MessageEntity? lastMessage;
  final int unreadCount;
  final bool muted;

  /// TTL исчезающих сообщений для этого чата в секундах.
  /// 0 или null — выключено.
  final int selfDestructSeconds;

  bool get hasSelfDestruct => selfDestructSeconds > 0;

  bool get isDm => kind == ConversationKind.dm;
  bool get isGroup => kind == ConversationKind.group;
  bool get isSaved => kind == ConversationKind.saved;

  /// Заголовок диалога: peer для DM, заданный title для группы,
  /// «Saved Messages» для Saved.
  String get effectiveTitle {
    switch (kind) {
      case ConversationKind.dm:
        return peer?.effectiveName ?? title ?? '—';
      case ConversationKind.group:
        return (title?.trim().isNotEmpty ?? false)
            ? title!.trim()
            : 'Группа';
      case ConversationKind.saved:
        return 'Saved Messages';
    }
  }

  ConversationEntity copyWith({
    String? id,
    ConversationKind? kind,
    DateTime? updatedAt,
    List<ConversationMember>? members,
    String? title,
    String? avatarPath,
    ProfileEntity? peer,
    MessageEntity? lastMessage,
    int? unreadCount,
    bool? muted,
    int? selfDestructSeconds,
  }) {
    return ConversationEntity(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      updatedAt: updatedAt ?? this.updatedAt,
      members: members ?? this.members,
      title: title ?? this.title,
      avatarPath: avatarPath ?? this.avatarPath,
      peer: peer ?? this.peer,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      muted: muted ?? this.muted,
      selfDestructSeconds: selfDestructSeconds ?? this.selfDestructSeconds,
    );
  }
}
