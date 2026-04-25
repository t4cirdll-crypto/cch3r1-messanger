import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Обёртка над sqflite: кэш профиля / чатов / сообщений.
class LocalDatabase {
  LocalDatabase._(this._db);

  final Database _db;
  Database get db => _db;

  static const int _version = 4;
  static const String _dbName = 'cchr_messanger.db';

  static Future<LocalDatabase> open() async {
    final String dir = (await getApplicationDocumentsDirectory()).path;
    final String path = p.join(dir, _dbName);
    final Database db = await openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return LocalDatabase._(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      const List<String> alters = <String>[
        'ALTER TABLE messages ADD COLUMN attachment_path TEXT;',
        'ALTER TABLE messages ADD COLUMN attachment_kind TEXT;',
        'ALTER TABLE messages ADD COLUMN attachment_name TEXT;',
        'ALTER TABLE messages ADD COLUMN attachment_mime TEXT;',
        'ALTER TABLE messages ADD COLUMN attachment_size INTEGER;',
        'ALTER TABLE messages ADD COLUMN attachment_duration_ms INTEGER;',
        'ALTER TABLE messages ADD COLUMN attachment_width INTEGER;',
        'ALTER TABLE messages ADD COLUMN attachment_height INTEGER;',
      ];
      for (final String sql in alters) {
        try {
          await db.execute(sql);
        } on DatabaseException {
          // Колонка уже добавлена — пропускаем.
        }
      }
    }
    if (oldVersion < 3) {
      const List<String> alters = <String>[
        'ALTER TABLE messages ADD COLUMN edited_at INTEGER;',
        'ALTER TABLE messages ADD COLUMN deleted_at INTEGER;',
        'ALTER TABLE messages ADD COLUMN reply_to_id TEXT;',
        'ALTER TABLE messages ADD COLUMN forwarded_from_message_id TEXT;',
        'ALTER TABLE messages ADD COLUMN forwarded_from_sender_id TEXT;',
        'ALTER TABLE messages ADD COLUMN pinned_at INTEGER;',
      ];
      for (final String sql in alters) {
        try {
          await db.execute(sql);
        } on DatabaseException {
          // Колонка уже добавлена — пропускаем.
        }
      }
      try {
        await db.execute('''
          CREATE TABLE message_reactions (
            message_id TEXT NOT NULL,
            user_id TEXT NOT NULL,
            emoji TEXT NOT NULL,
            created_at INTEGER,
            PRIMARY KEY (message_id, user_id, emoji)
          );
        ''');
        await db.execute(
          'CREATE INDEX idx_reactions_message '
          'ON message_reactions (message_id);',
        );
      } on DatabaseException {
        // Таблица уже создана.
      }
    }
    if (oldVersion < 4) {
      // Phase 2: groups + Saved Messages. Кэш формата 1:1 не совместим
      // с новой схемой (peer может быть null, появились kind/title/avatar).
      // Простой и безопасный путь — пересоздать таблицу.
      try {
        await db.execute('DROP TABLE IF EXISTS conversations;');
      } on DatabaseException {
        // Игнорируем ошибки удаления.
      }
      await db.execute('''
        CREATE TABLE conversations (
          id TEXT PRIMARY KEY,
          kind TEXT NOT NULL DEFAULT 'dm',
          title TEXT,
          avatar_path TEXT,
          peer_id TEXT,
          peer_username TEXT,
          peer_display_name TEXT,
          peer_avatar_url TEXT,
          peer_is_online INTEGER NOT NULL DEFAULT 0,
          peer_last_seen INTEGER,
          last_message_id TEXT,
          last_message_content TEXT,
          last_message_sender_id TEXT,
          last_message_is_read INTEGER,
          last_message_created_at INTEGER,
          unread_count INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL,
          muted INTEGER NOT NULL DEFAULT 0
        );
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_conversations_updated '
        'ON conversations (updated_at DESC);',
      );
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        display_name TEXT,
        avatar_url TEXT,
        is_online INTEGER NOT NULL DEFAULT 0,
        last_seen INTEGER,
        created_at INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE conversations (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL DEFAULT 'dm',
        title TEXT,
        avatar_path TEXT,
        peer_id TEXT,
        peer_username TEXT,
        peer_display_name TEXT,
        peer_avatar_url TEXT,
        peer_is_online INTEGER NOT NULL DEFAULT 0,
        peer_last_seen INTEGER,
        last_message_id TEXT,
        last_message_content TEXT,
        last_message_sender_id TEXT,
        last_message_is_read INTEGER,
        last_message_created_at INTEGER,
        unread_count INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL,
        muted INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT,
        is_read INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        edited_at INTEGER,
        deleted_at INTEGER,
        reply_to_id TEXT,
        forwarded_from_message_id TEXT,
        forwarded_from_sender_id TEXT,
        pinned_at INTEGER,
        attachment_path TEXT,
        attachment_kind TEXT,
        attachment_name TEXT,
        attachment_mime TEXT,
        attachment_size INTEGER,
        attachment_duration_ms INTEGER,
        attachment_width INTEGER,
        attachment_height INTEGER
      );
    ''');
    await db.execute('''
      CREATE TABLE message_reactions (
        message_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        emoji TEXT NOT NULL,
        created_at INTEGER,
        PRIMARY KEY (message_id, user_id, emoji)
      );
    ''');
    await db.execute(
      'CREATE INDEX idx_reactions_message '
      'ON message_reactions (message_id);',
    );
    await db.execute(
      'CREATE INDEX idx_messages_conv_created '
      'ON messages (conversation_id, created_at DESC);',
    );
    await db.execute(
      'CREATE INDEX idx_conversations_updated '
      'ON conversations (updated_at DESC);',
    );
  }

  Future<void> close() => _db.close();
}

final Provider<Future<LocalDatabase>> localDatabaseProvider =
    Provider<Future<LocalDatabase>>((Ref ref) async {
  final LocalDatabase db = await LocalDatabase.open();
  ref.onDispose(() async => db.close());
  return db;
});
