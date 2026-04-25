/// Сводная статистика для главной админки.
class AdminStats {
  const AdminStats({
    required this.usersTotal,
    required this.usersBanned,
    required this.usersOnline,
    required this.conversationsTotal,
    required this.groupsTotal,
    required this.messagesTotal,
    required this.messagesToday,
  });

  final int usersTotal;
  final int usersBanned;
  final int usersOnline;
  final int conversationsTotal;
  final int groupsTotal;
  final int messagesTotal;
  final int messagesToday;

  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
        usersTotal: (j['users_total'] as num?)?.toInt() ?? 0,
        usersBanned: (j['users_banned'] as num?)?.toInt() ?? 0,
        usersOnline: (j['users_online'] as num?)?.toInt() ?? 0,
        conversationsTotal:
            (j['conversations_total'] as num?)?.toInt() ?? 0,
        groupsTotal: (j['groups_total'] as num?)?.toInt() ?? 0,
        messagesTotal: (j['messages_total'] as num?)?.toInt() ?? 0,
        messagesToday: (j['messages_today'] as num?)?.toInt() ?? 0,
      );
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.isOnline,
    this.lastSeen,
    required this.createdAt,
    this.bio,
    required this.isBanned,
    this.bannedAt,
    this.bannedReason,
    this.email,
    required this.messageCount,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;
  final String? bio;
  final bool isBanned;
  final DateTime? bannedAt;
  final String? bannedReason;
  final String? email;
  final int messageCount;

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: j['id'] as String,
        username: j['username'] as String,
        displayName: j['display_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        isOnline: (j['is_online'] as bool?) ?? false,
        lastSeen: _parseDate(j['last_seen']),
        createdAt: _parseDate(j['created_at']) ?? DateTime.now(),
        bio: j['bio'] as String?,
        isBanned: (j['is_banned'] as bool?) ?? false,
        bannedAt: _parseDate(j['banned_at']),
        bannedReason: j['banned_reason'] as String?,
        email: j['email'] as String?,
        messageCount: (j['message_count'] as num?)?.toInt() ?? 0,
      );
}

class AdminConversationMember {
  const AdminConversationMember({
    required this.userId,
    this.username,
    this.displayName,
    this.role,
  });

  final String userId;
  final String? username;
  final String? displayName;
  final String? role;

  factory AdminConversationMember.fromJson(Map<String, dynamic> j) =>
      AdminConversationMember(
        userId: j['user_id'] as String,
        username: j['username'] as String?,
        displayName: j['display_name'] as String?,
        role: j['role'] as String?,
      );
}

class AdminConversation {
  const AdminConversation({
    required this.id,
    required this.kind,
    this.title,
    required this.createdAt,
    this.updatedAt,
    required this.members,
    required this.messageCount,
  });

  final String id;
  final String kind;
  final String? title;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<AdminConversationMember> members;
  final int messageCount;

  factory AdminConversation.fromJson(Map<String, dynamic> j) =>
      AdminConversation(
        id: j['id'] as String,
        kind: (j['kind'] as String?) ?? 'dm',
        title: j['title'] as String?,
        createdAt: _parseDate(j['created_at']) ?? DateTime.now(),
        updatedAt: _parseDate(j['updated_at']),
        members: ((j['members'] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic e) =>
                AdminConversationMember.fromJson(e as Map<String, dynamic>))
            .toList(),
        messageCount: (j['message_count'] as num?)?.toInt() ?? 0,
      );
}

class AdminMessage {
  const AdminMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderUsername,
    this.content,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.expiresAt,
    this.attachmentPath,
    this.attachmentKind,
    this.attachmentName,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String? senderUsername;
  final String? content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime? expiresAt;
  final String? attachmentPath;
  final String? attachmentKind;
  final String? attachmentName;

  factory AdminMessage.fromJson(Map<String, dynamic> j) => AdminMessage(
        id: j['id'] as String,
        conversationId: j['conversation_id'] as String,
        senderId: j['sender_id'] as String,
        senderUsername: j['sender_username'] as String?,
        content: j['content'] as String?,
        createdAt: _parseDate(j['created_at']) ?? DateTime.now(),
        editedAt: _parseDate(j['edited_at']),
        deletedAt: _parseDate(j['deleted_at']),
        expiresAt: _parseDate(j['expires_at']),
        attachmentPath: j['attachment_path'] as String?,
        attachmentKind: j['attachment_kind'] as String?,
        attachmentName: j['attachment_name'] as String?,
      );
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toLocal();
  return null;
}
