import 'package:flutter_test/flutter_test.dart';
import 'package:cch3r1_messanger/features/auth/domain/entities/profile_entity.dart';
import 'package:cch3r1_messanger/features/chat_list/domain/entities/conversation_entity.dart';
import 'package:cch3r1_messanger/features/chat_list/presentation/utils/conversation_filter.dart';

void main() {
  final List<ConversationEntity> conversations = <ConversationEntity>[
    ConversationEntity(
        id: 'dm',
        kind: ConversationKind.dm,
        updatedAt: DateTime(2026),
        members: const [],
        unreadCount: 2,
        peer: const ProfileEntity(
            id: 'peer', username: 'max_orlov', displayName: 'Максим Орлов')),
    ConversationEntity(
        id: 'group',
        kind: ConversationKind.group,
        updatedAt: DateTime(2026),
        members: const [],
        title: 'Дизайн-команда'),
    ConversationEntity(
        id: 'saved',
        kind: ConversationKind.saved,
        updatedAt: DateTime(2026),
        members: const []),
  ];

  List<String> ids(String query, ConversationFilter filter) =>
      filterConversations(conversations, query: query, filter: filter)
          .map((c) => c.id)
          .toList();

  test('search matches names and @usernames ignoring case and whitespace', () {
    expect(ids('  МАКСИМ ', ConversationFilter.all), ['dm']);
    expect(ids(' @MAX_ORLOV ', ConversationFilter.all), ['dm']);
    expect(ids('дизайн', ConversationFilter.all), ['group']);
    expect(ids('избранное', ConversationFilter.all), ['saved']);
  });

  test('filters combine with search without reordering the source', () {
    expect(ids('', ConversationFilter.unread), ['dm']);
    expect(ids('', ConversationFilter.groups), ['group']);
    expect(ids('максим', ConversationFilter.groups), isEmpty);
    expect(ids(' ', ConversationFilter.all), ['dm', 'group', 'saved']);
    expect(conversations.map((c) => c.id), ['dm', 'group', 'saved']);
  });
}
