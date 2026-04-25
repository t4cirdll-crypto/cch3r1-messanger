import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart' as app;
import '../../domain/entities/conversation_entity.dart';
import '../../domain/repositories/chat_list_repository.dart';
import '../datasources/chat_list_local_datasource.dart';
import '../datasources/chat_list_remote_datasource.dart';
import '../models/conversation_model.dart';

class ChatListRepositoryImpl implements ChatListRepository {
  ChatListRepositoryImpl({
    required this.remote,
    required this.local,
    required this.client,
  });

  final ChatListRemoteDataSource remote;
  final ChatListLocalDataSource local;
  final SupabaseClient client;

  String get _uid {
    final User? u = client.auth.currentUser;
    if (u == null) throw const app.AuthException('Нет активной сессии');
    return u.id;
  }

  @override
  Future<List<ConversationEntity>> getConversations() async {
    try {
      final List<ConversationModel> remoteList =
          await remote.getConversations(_uid);
      final List<ConversationEntity> entities = remoteList
          .map((ConversationModel c) => c.toEntity(_uid))
          .toList();
      await local.cache(entities);
      return entities;
    } catch (_) {
      return local.getCached();
    }
  }

  @override
  Future<ConversationEntity> createOrGetConversation(String peerId) async {
    final ConversationModel model =
        await remote.createOrGetConversation(_uid, peerId);
    return model.toEntity(_uid);
  }

  @override
  Stream<void> watchConversationChanges() => remote.watchChanges(_uid);
}
