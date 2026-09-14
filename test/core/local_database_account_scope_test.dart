import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'package:cch3r1_messanger/core/db/local_database.dart';
import 'package:cch3r1_messanger/core/errors/exceptions.dart';
import 'package:cch3r1_messanger/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:cch3r1_messanger/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:cch3r1_messanger/features/auth/data/models/profile_model.dart';
import 'package:cch3r1_messanger/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:cch3r1_messanger/features/chat/data/datasources/chat_local_datasource.dart';
import 'package:cch3r1_messanger/features/chat/data/models/message_model.dart';
import 'package:cch3r1_messanger/features/chat/data/models/reaction_model.dart';
import 'package:cch3r1_messanger/features/chat/domain/entities/message_entity.dart';
import 'package:cch3r1_messanger/features/chat_list/data/datasources/chat_list_local_datasource.dart';
import 'package:cch3r1_messanger/features/chat_list/domain/entities/conversation_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('LocalDatabase account-scoped cache', () {
    late LocalDatabase database;
    late AuthLocalDataSource authCache;
    late ChatLocalDataSource chatCache;
    late ChatListLocalDataSource chatListCache;

    setUp(() async {
      database = await LocalDatabase.openForTesting(databaseFactoryFfi);
      authCache = AuthLocalDataSource(database);
      chatCache = ChatLocalDataSource(database);
      chatListCache = ChatListLocalDataSource(database);
    });

    tearDown(() => database.close());

    test('keeps account A cache unavailable after switching to account B',
        () async {
      final DateTime createdAt = DateTime.utc(2026, 9, 14, 4, 5);
      final DateTime deletedAt = DateTime.utc(2026, 9, 14, 4, 6);
      final DateTime expiresAt = DateTime.utc(2020, 1, 2);

      await authCache.cacheProfile(
        'account-a',
        const ProfileModel(id: 'shared-peer', username: 'alice-peer'),
      );
      await authCache.cacheProfile(
        'account-b',
        const ProfileModel(id: 'shared-peer', username: 'bob-peer'),
      );

      await chatCache.cacheAll(
        'account-a',
        'shared-conversation',
        <MessageModel>[
          MessageModel(
            id: 'shared-message',
            conversationId: 'shared-conversation',
            senderId: 'shared-peer',
            content: 'account A private text',
            createdAt: createdAt,
          ),
        ],
      );
      await chatCache.cacheAll(
        'account-b',
        'shared-conversation',
        <MessageModel>[
          MessageModel(
            id: 'shared-message',
            conversationId: 'shared-conversation',
            senderId: 'shared-peer',
            content: 'account B private text',
            createdAt: createdAt,
          ),
        ],
      );
      await chatCache.upsertReaction(
        'account-a',
        ReactionModel(
          messageId: 'shared-message',
          userId: 'account-a',
          emoji: '👍',
          createdAt: createdAt,
        ),
      );
      await chatCache.upsertReaction(
        'account-b',
        ReactionModel(
          messageId: 'shared-message',
          userId: 'account-b',
          emoji: '❤️',
          createdAt: createdAt,
        ),
      );

      await chatListCache.cache(
        'account-a',
        <ConversationEntity>[
          _conversation(
            content: 'expired account A text',
            createdAt: createdAt,
            deletedAt: deletedAt,
            expiresAt: expiresAt,
            attachmentName: 'account-a.pdf',
          ),
        ],
      );
      await chatListCache.cache(
        'account-b',
        <ConversationEntity>[
          _conversation(
            content: 'account B text',
            createdAt: createdAt,
            attachmentName: 'account-b.pdf',
          ),
        ],
      );

      expect(
        (await authCache.getProfile('account-a', 'shared-peer'))?.username,
        'alice-peer',
      );
      expect(
        (await authCache.getProfile('account-b', 'shared-peer'))?.username,
        'bob-peer',
      );
      expect(
        await authCache.getProfile('account-b', 'account-a'),
        isNull,
      );

      expect(
        (await chatCache.getMessages('account-a', 'shared-conversation'))
            .single
            .content,
        'account A private text',
      );
      expect(
        (await chatCache.getMessages('account-b', 'shared-conversation'))
            .single
            .content,
        'account B private text',
      );
      expect(
        (await chatCache.getReactions('account-a', <String>['shared-message']))
            .single
            .emoji,
        '👍',
      );
      expect(
        (await chatCache.getReactions('account-b', <String>['shared-message']))
            .single
            .emoji,
        '❤️',
      );

      final MessageEntity accountALastMessage =
          (await chatListCache.getCached('account-a')).single.lastMessage!;
      final MessageEntity accountBLastMessage =
          (await chatListCache.getCached('account-b')).single.lastMessage!;
      expect(accountALastMessage.content, 'expired account A text');
      expect(accountALastMessage.deletedAt, isNotNull);
      expect(
        accountALastMessage.deletedAt!.isAtSameMomentAs(deletedAt),
        isTrue,
      );
      expect(accountALastMessage.expiresAt, isNotNull);
      expect(
        accountALastMessage.expiresAt!.isAtSameMomentAs(expiresAt),
        isTrue,
      );
      expect(accountALastMessage.attachmentKind, AttachmentKind.file);
      expect(accountALastMessage.attachmentName, 'account-a.pdf');
      expect(accountALastMessage.isDeleted, isTrue);
      expect(accountALastMessage.isExpired, isTrue);
      expect(accountBLastMessage.content, 'account B text');
      expect(accountBLastMessage.attachmentName, 'account-b.pdf');

      await chatListCache.cache('account-a', <ConversationEntity>[]);
      expect(await chatListCache.getCached('account-a'), isEmpty);
      expect(
          (await chatListCache.getCached('account-b'))
              .single
              .lastMessage!
              .content,
          'account B text');
    });

    test('v9 replaces only cache tables during upgrade', () async {
      final Directory temporaryDirectory =
          await Directory.systemTemp.createTemp('cchr-cache-upgrade-');
      final String path = '${temporaryDirectory.path}/cache.db';
      final Database legacy = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (Database db, int _) async {
            await db.execute('CREATE TABLE profiles (id TEXT PRIMARY KEY)');
            await db
                .execute('CREATE TABLE conversations (id TEXT PRIMARY KEY)');
            await db.execute('CREATE TABLE messages (id TEXT PRIMARY KEY)');
            await db.execute('''
              CREATE TABLE message_reactions (
                message_id TEXT,
                user_id TEXT,
                emoji TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE user_owned_data (
                id TEXT PRIMARY KEY,
                content TEXT NOT NULL
              )
            ''');
            await db.insert(
              'user_owned_data',
              <String, Object?>{'id': 'keep', 'content': 'must survive'},
            );
          },
        ),
      );
      await legacy.close();

      final LocalDatabase upgraded = await LocalDatabase.openForTesting(
        databaseFactoryFfi,
        path: path,
      );
      addTearDown(() async {
        await upgraded.close();
        await databaseFactoryFfi.deleteDatabase(path);
        await temporaryDirectory.delete(recursive: true);
      });

      expect(
        await upgraded.db.query('user_owned_data'),
        <Map<String, Object?>>[
          <String, Object?>{'id': 'keep', 'content': 'must survive'},
        ],
      );
      final List<Map<String, Object?>> columns =
          await upgraded.db.rawQuery('PRAGMA table_info(conversations)');
      final Set<String> names = columns
          .map((Map<String, Object?> row) => row['name']! as String)
          .toSet();
      expect(
        names,
        containsAll(<String>[
          'account_id',
          'last_message_deleted_at',
          'last_message_expires_at',
          'last_message_attachment_kind',
          'last_message_attachment_name',
        ]),
      );
    });

    test('does not return or cache a stale profile after account switch',
        () async {
      String? currentAccountId = 'account-a';
      final _DeferredAuthRemoteDataSource remote =
          _DeferredAuthRemoteDataSource();
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        remote: remote,
        local: authCache,
        currentAccountId: () => currentAccountId,
      );

      final Future<void> result = repository.getCurrentProfile();
      currentAccountId = 'account-b';
      remote.profile.complete(
        const ProfileModel(id: 'account-a', username: 'alice'),
      );

      await expectLater(result, throwsA(isA<AuthException>()));
      expect(await authCache.getProfile('account-a', 'account-a'), isNull);
      expect(await authCache.getProfile('account-b', 'account-a'), isNull);
    });

    test('does not use offline profile cache after account switch', () async {
      String? currentAccountId = 'account-a';
      final _DeferredAuthRemoteDataSource remote =
          _DeferredAuthRemoteDataSource();
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        remote: remote,
        local: authCache,
        currentAccountId: () => currentAccountId,
      );
      await authCache.cacheProfile(
        'account-a',
        const ProfileModel(id: 'account-a', username: 'alice'),
      );
      await authCache.cacheProfile(
        'account-b',
        const ProfileModel(id: 'account-b', username: 'bob'),
      );

      final Future<void> result = repository.getCurrentProfile();
      currentAccountId = 'account-b';
      remote.profile.completeError(const NetworkException());

      await expectLater(result, throwsA(isA<AuthException>()));
    });

    test('clears only the captured account cache after sign-out', () async {
      String? currentAccountId = 'account-a';
      final AuthRepositoryImpl repository = AuthRepositoryImpl(
        remote: _SwitchingSignOutRemoteDataSource(
          () => currentAccountId = 'account-b',
        ),
        local: authCache,
        currentAccountId: () => currentAccountId,
      );
      await authCache.cacheProfile(
        'account-a',
        const ProfileModel(id: 'account-a', username: 'alice'),
      );
      await authCache.cacheProfile(
        'account-b',
        const ProfileModel(id: 'account-b', username: 'bob'),
      );

      await repository.signOut();

      expect(await authCache.getProfile('account-a', 'account-a'), isNull);
      expect(
        (await authCache.getProfile('account-b', 'account-b'))?.username,
        'bob',
      );
    });
  });
}

class _DeferredAuthRemoteDataSource extends AuthRemoteDataSource {
  _DeferredAuthRemoteDataSource()
      : super(SupabaseClient('http://localhost', 'test-key'));

  final Completer<ProfileModel?> profile = Completer<ProfileModel?>();

  @override
  Future<ProfileModel?> getCurrentProfile() => profile.future;
}

class _SwitchingSignOutRemoteDataSource extends AuthRemoteDataSource {
  _SwitchingSignOutRemoteDataSource(this._onSignOut)
      : super(SupabaseClient('http://localhost', 'test-key'));

  final void Function() _onSignOut;

  @override
  Future<void> setOnline(bool online) async {}

  @override
  Future<void> signOut() async {
    _onSignOut();
  }
}

ConversationEntity _conversation({
  required String content,
  required DateTime createdAt,
  DateTime? deletedAt,
  DateTime? expiresAt,
  String? attachmentName,
}) {
  return ConversationEntity(
    id: 'shared-conversation',
    kind: ConversationKind.dm,
    updatedAt: createdAt,
    members: const <ConversationMember>[],
    lastMessage: MessageEntity(
      id: 'shared-message',
      conversationId: 'shared-conversation',
      senderId: 'shared-peer',
      content: content,
      createdAt: createdAt,
      deletedAt: deletedAt,
      expiresAt: expiresAt,
      attachmentKind: AttachmentKind.file,
      attachmentName: attachmentName,
    ),
  );
}
