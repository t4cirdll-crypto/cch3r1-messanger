import 'package:sqflite/sqflite.dart';

import '../../../../core/db/local_database.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../chat/domain/entities/message_entity.dart';
import '../../domain/entities/conversation_entity.dart';

/// Кэш списка диалогов в SQLite. Хранит «расхлопнутый» представление —
/// peer (если DM) и краткое описание last_message; группы / Saved живут
/// без peer-полей (peer_id NULL).
class ChatListLocalDataSource {
  ChatListLocalDataSource(this._db);
  final LocalDatabase _db;

  static const int _cacheLimit = 50;

  Future<List<ConversationEntity>> getCached() async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'conversations',
      orderBy: 'updated_at DESC',
      limit: _cacheLimit,
    );
    return rows.map(_rowToEntity).toList();
  }

  Future<void> cache(List<ConversationEntity> conversations) async {
    final Batch batch = _db.db.batch();
    batch.delete('conversations');
    for (final ConversationEntity c in conversations.take(_cacheLimit)) {
      batch.insert(
        'conversations',
        _entityToRow(c),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Map<String, Object?> _entityToRow(ConversationEntity c) => <String, Object?>{
        'id': c.id,
        'kind': c.kind.value,
        'title': c.title,
        'avatar_path': c.avatarPath,
        'peer_id': c.peer?.id,
        'peer_username': c.peer?.username,
        'peer_display_name': c.peer?.displayName,
        'peer_avatar_url': c.peer?.avatarUrl,
        'peer_is_online': (c.peer?.isOnline ?? false) ? 1 : 0,
        'peer_last_seen': c.peer?.lastSeen?.millisecondsSinceEpoch,
        'last_message_id': c.lastMessage?.id,
        'last_message_content': c.lastMessage?.content,
        'last_message_sender_id': c.lastMessage?.senderId,
        'last_message_is_read':
            c.lastMessage == null ? null : (c.lastMessage!.isRead ? 1 : 0),
        'last_message_created_at':
            c.lastMessage?.createdAt.millisecondsSinceEpoch,
        'unread_count': c.unreadCount,
        'updated_at': c.updatedAt.millisecondsSinceEpoch,
        'muted': c.muted ? 1 : 0,
      };

  ConversationEntity _rowToEntity(Map<String, Object?> row) {
    final ConversationKind kind =
        ConversationKind.fromString(row['kind'] as String?);
    ProfileEntity? peer;
    final String? peerId = row['peer_id'] as String?;
    if (peerId != null) {
      peer = ProfileEntity(
        id: peerId,
        username: (row['peer_username'] as String?) ?? '',
        displayName: row['peer_display_name'] as String?,
        avatarUrl: row['peer_avatar_url'] as String?,
        isOnline: ((row['peer_is_online'] as int?) ?? 0) == 1,
        lastSeen: row['peer_last_seen'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row['peer_last_seen']! as int,
              ),
      );
    }
    MessageEntity? last;
    if (row['last_message_id'] != null) {
      last = MessageEntity(
        id: row['last_message_id']! as String,
        conversationId: row['id']! as String,
        senderId: row['last_message_sender_id']! as String,
        content: row['last_message_content'] as String?,
        isRead: ((row['last_message_is_read'] as int?) ?? 0) == 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['last_message_created_at']! as int,
        ),
      );
    }
    return ConversationEntity(
      id: row['id']! as String,
      kind: kind,
      title: row['title'] as String?,
      avatarPath: row['avatar_path'] as String?,
      peer: peer,
      members: const <ConversationMember>[],
      lastMessage: last,
      unreadCount: (row['unread_count'] as int?) ?? 0,
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
      muted: ((row['muted'] as int?) ?? 0) == 1,
    );
  }
}
