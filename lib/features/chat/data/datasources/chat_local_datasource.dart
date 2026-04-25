import 'package:sqflite/sqflite.dart';

import '../../../../core/db/local_database.dart';
import '../models/message_model.dart';
import '../models/reaction_model.dart';

class ChatLocalDataSource {
  ChatLocalDataSource(this._db);
  final LocalDatabase _db;

  static const int _perChatLimit = 100;

  Future<List<MessageModel>> getMessages(String conversationId) async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: <Object>[conversationId],
      orderBy: 'created_at DESC',
      limit: _perChatLimit,
    );
    return rows.map(MessageModel.fromDb).toList();
  }

  Future<MessageModel?> getById(String id) async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'messages',
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MessageModel.fromDb(rows.first);
  }

  Future<void> cacheAll(String conversationId, List<MessageModel> messages) async {
    final Batch batch = _db.db.batch();
    for (final MessageModel m in messages) {
      batch.insert(
        'messages',
        m.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await _db.db.rawDelete(
      '''
      DELETE FROM messages
      WHERE conversation_id = ?
        AND id NOT IN (
          SELECT id FROM messages
          WHERE conversation_id = ?
          ORDER BY created_at DESC
          LIMIT ?
        )
      ''',
      <Object>[conversationId, conversationId, _perChatLimit],
    );
  }

  Future<void> upsert(MessageModel m) async {
    await _db.db.insert(
      'messages',
      m.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    await _db.db.delete('messages', where: 'id = ?', whereArgs: <Object>[id]);
    await _db.db.delete(
      'message_reactions',
      where: 'message_id = ?',
      whereArgs: <Object>[id],
    );
  }

  Future<List<ReactionModel>> getReactions(List<String> messageIds) async {
    if (messageIds.isEmpty) return <ReactionModel>[];
    final String placeholders = List<String>.filled(messageIds.length, '?').join(',');
    final List<Map<String, Object?>> rows = await _db.db.query(
      'message_reactions',
      where: 'message_id IN ($placeholders)',
      whereArgs: messageIds,
    );
    return rows.map(ReactionModel.fromDb).toList();
  }

  Future<void> upsertReactions(List<ReactionModel> reactions) async {
    if (reactions.isEmpty) return;
    final Batch batch = _db.db.batch();
    for (final ReactionModel r in reactions) {
      batch.insert(
        'message_reactions',
        r.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertReaction(ReactionModel r) async {
    await _db.db.insert(
      'message_reactions',
      r.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _db.db.delete(
      'message_reactions',
      where: 'message_id = ? AND user_id = ? AND emoji = ?',
      whereArgs: <Object>[messageId, userId, emoji],
    );
  }

  Future<void> deleteReactionsForMessage(String messageId) async {
    await _db.db.delete(
      'message_reactions',
      where: 'message_id = ?',
      whereArgs: <Object>[messageId],
    );
  }
}
