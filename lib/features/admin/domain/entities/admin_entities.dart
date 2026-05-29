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
        usersTotal: _parseInt(j['users_total']),
        usersBanned: _parseInt(j['users_banned']),
        usersOnline: _parseInt(j['users_online']),
        conversationsTotal: _parseInt(j['conversations_total']),
        groupsTotal: _parseInt(j['groups_total']),
        messagesTotal: _parseInt(j['messages_total']),
        messagesToday: _parseInt(j['messages_today']),
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
    this.rank,
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
  final String? rank;

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: (j['id'] ?? '').toString(),
        username: (j['username'] ?? '').toString(),
        displayName: j['display_name']?.toString(),
        avatarUrl: j['avatar_url']?.toString(),
        isOnline: j['is_online'] == true,
        lastSeen: _parseDate(j['last_seen']),
        createdAt: _parseDate(j['created_at']) ?? DateTime.now(),
        bio: j['bio']?.toString(),
        isBanned: j['is_banned'] == true,
        bannedAt: _parseDate(j['banned_at']),
        bannedReason: j['banned_reason']?.toString(),
        email: j['email']?.toString(),
        messageCount: _parseInt(j['message_count']),
        rank: j['rank']?.toString(),
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
        id: (j['id'] ?? '').toString(),
        kind: (j['kind'] as String?) ?? 'dm',
        title: j['title'] as String?,
        createdAt: _parseDate(j['created_at']) ?? DateTime.now(),
        updatedAt: _parseDate(j['updated_at']),
        members: ((j['members'] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic e) =>
                AdminConversationMember.fromJson(e as Map<String, dynamic>))
            .toList(),
        messageCount: _parseInt(j['message_count']),
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

int _parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
