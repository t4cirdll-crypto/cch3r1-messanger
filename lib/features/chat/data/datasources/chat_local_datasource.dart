import 'package:sqflite/sqflite.dart';

import '../../../../core/db/local_database.dart';
import '../models/message_model.dart';
import '../models/reaction_model.dart';

class ChatLocalDataSource {
  ChatLocalDataSource(this._db);
  final LocalDatabase _db;

  static const int _perChatLimit = 100;

  Future<List<MessageModel>> getMessages(
    String accountId,
    String conversationId,
  ) async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'messages',
      where: 'account_id = ? AND conversation_id = ?',
      whereArgs: <Object>[accountId, conversationId],
      orderBy: 'created_at DESC',
      limit: _perChatLimit,
    );
    return rows.map(MessageModel.fromDb).toList();
  }

  Future<MessageModel?> getById(String accountId, String id) async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'messages',
      where: 'account_id = ? AND id = ?',
      whereArgs: <Object>[accountId, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MessageModel.fromDb(rows.first);
  }

  Future<void> cacheAll(
    String accountId,
    String conversationId,
    List<MessageModel> messages,
  ) async {
    final Batch batch = _db.db.batch();
    for (final MessageModel m in messages) {
      batch.insert(
        'messages',
        _messageRow(accountId, m),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await _db.db.rawDelete(
      '''
      DELETE FROM messages
      WHERE account_id = ?
        AND conversation_id = ?
        AND id NOT IN (
          SELECT id FROM messages
          WHERE account_id = ?
            AND conversation_id = ?
          ORDER BY created_at DESC
          LIMIT ?
        )
      ''',
      <Object>[accountId, conversationId, accountId, conversationId, _perChatLimit],
    );
  }

  Future<void> upsert(String accountId, MessageModel m) async {
    await _db.db.insert(
      'messages',
      _messageRow(accountId, m),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String accountId, String id) async {
    await _db.db.delete(
      'messages',
      where: 'account_id = ? AND id = ?',
      whereArgs: <Object>[accountId, id],
    );
    await _db.db.delete(
      'message_reactions',
      where: 'account_id = ? AND message_id = ?',
      whereArgs: <Object>[accountId, id],
    );
  }

  Future<List<ReactionModel>> getReactions(
    String accountId,
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return <ReactionModel>[];
    final String placeholders = List<String>.filled(messageIds.length, '?').join(',');
    final List<Map<String, Object?>> rows = await _db.db.query(
      'message_reactions',
      where: 'account_id = ? AND message_id IN ($placeholders)',
      whereArgs: <Object>[accountId, ...messageIds],
    );
    return rows.map(ReactionModel.fromDb).toList();
  }

  Future<void> upsertReactions(
    String accountId,
    List<ReactionModel> reactions,
  ) async {
    if (reactions.isEmpty) return;
    final Batch batch = _db.db.batch();
    for (final ReactionModel r in reactions) {
      batch.insert(
        'message_reactions',
        _reactionRow(accountId, r),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertReaction(String accountId, ReactionModel r) async {
    await _db.db.insert(
      'message_reactions',
      _reactionRow(accountId, r),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteReaction({
    required String accountId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _db.db.delete(
      'message_reactions',
      where:
          'account_id = ? AND message_id = ? AND user_id = ? AND emoji = ?',
      whereArgs: <Object>[accountId, messageId, userId, emoji],
    );
  }

  Future<void> deleteReactionsForMessage(
    String accountId,
    String messageId,
  ) async {
    await _db.db.delete(
      'message_reactions',
      where: 'account_id = ? AND message_id = ?',
      whereArgs: <Object>[accountId, messageId],
    );
  }

  Map<String, Object?> _messageRow(String accountId, MessageModel message) =>
      <String, Object?>{
        'account_id': accountId,
        ...message.toDb(),
      };

  Map<String, Object?> _reactionRow(String accountId, ReactionModel reaction) =>
      <String, Object?>{
        'account_id': accountId,
        ...reaction.toDb(),
      };
}
