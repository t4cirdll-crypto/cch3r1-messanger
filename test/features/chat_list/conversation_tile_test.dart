import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cch3r1_messanger/config/theme.dart';
import 'package:cch3r1_messanger/core/constants/app_strings.dart';
import 'package:cch3r1_messanger/core/widgets/user_avatar.dart';
import 'package:cch3r1_messanger/features/auth/domain/entities/profile_entity.dart';
import 'package:cch3r1_messanger/features/chat/domain/entities/message_entity.dart';
import 'package:cch3r1_messanger/features/chat_list/domain/entities/conversation_entity.dart';
import 'package:cch3r1_messanger/features/chat_list/presentation/widgets/conversation_tile.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  Future<void> pumpTile(WidgetTester tester, MessageEntity message) =>
      tester.pumpWidget(
        MaterialApp(
            theme: AppTheme.light(null),
            home: Scaffold(
                body: ConversationTile(
              conversation: ConversationEntity(
                  id: 'chat',
                  kind: ConversationKind.dm,
                  updatedAt: DateTime(2026, 9, 14),
                  members: const [],
                  peer: const ProfileEntity(
                      id: 'peer',
                      username: 'alina',
                      displayName: '👩🏽‍💻 Алина'),
                  lastMessage: message),
              currentUserId: 'self',
              onTap: () {},
            ))),
      );

  testWidgets('deleted messages never expose cached content in the inbox',
      (tester) async {
    await pumpTile(
        tester,
        MessageEntity(
            id: 'message',
            conversationId: 'chat',
            senderId: 'peer',
            createdAt: DateTime(2026, 9, 14),
            content: 'private cached text',
            deletedAt: DateTime(2026, 9, 14)));
    expect(find.text('private cached text'), findsNothing);
    expect(find.text(AppStrings.messageDeleted), findsOneWidget);
    expect(find.text('👩🏽‍💻'), findsOneWidget);
  });

  testWidgets('expired messages never expose cached content in the inbox',
      (tester) async {
    await pumpTile(
        tester,
        MessageEntity(
            id: 'message',
            conversationId: 'chat',
            senderId: 'peer',
            createdAt: DateTime(2020),
            content: 'expired cached text',
            expiresAt: DateTime(2020, 1, 2)));
    expect(find.text('expired cached text'), findsNothing);
    expect(find.text(AppStrings.messageExpired), findsOneWidget);
  });

  testWidgets('avatar decoding is bounded to its displayed pixel width',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(devicePixelRatio: 3),
      child: UserAvatar(
          radius: 26,
          initial: 'A',
          avatarUrl: 'https://example.invalid/avatar.jpg'),
    )));
    final CachedNetworkImage image =
        tester.widget(find.byType(CachedNetworkImage));
    expect(image.memCacheWidth, 156);
    expect(image.memCacheHeight, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
