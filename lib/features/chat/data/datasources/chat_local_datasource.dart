import 'package:sqflite/sqflite.dart';

import '../../../../core/db/local_database.dart';
import '../models/message_model.dart';

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
    // Подрезаем таблицу: оставляем лишь последние 100 сообщений диалога.
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
}
