import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cch3r1_messanger/core/constants/app_strings.dart';
import 'package:cch3r1_messanger/features/chat/domain/entities/message_entity.dart';
import 'package:cch3r1_messanger/features/chat/domain/repositories/chat_repository.dart';
import 'package:cch3r1_messanger/features/chat/presentation/providers/chat_providers.dart';
import 'package:cch3r1_messanger/features/chat/presentation/screens/in_chat_search_screen.dart';

class _SearchRepository implements ChatRepository {
  final Map<String, Completer<List<MessageEntity>>> requests = {};

  @override
  Future<List<MessageEntity>> searchInConversation({
    required String conversationId,
    required String query,
  }) =>
      requests.putIfAbsent(query, Completer<List<MessageEntity>>.new).future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MessageEntity _result(String text) => MessageEntity(
      id: text,
      conversationId: 'chat',
      senderId: 'peer',
      createdAt: DateTime(2026, 9, 14),
      content: text,
    );

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  Future<_SearchRepository> pumpSearch(WidgetTester tester) async {
    final _SearchRepository repository = _SearchRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [chatRepositoryProvider.overrideWith((_) async => repository)],
      child:
          const MaterialApp(home: InChatSearchScreen(conversationId: 'chat')),
    ));
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> query(WidgetTester tester, String value) async {
    await tester.enterText(
        find.byKey(const ValueKey<String>('message-search')), value);
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
  }

  testWidgets('late search response cannot replace a newer result',
      (tester) async {
    final _SearchRepository repository = await pumpSearch(tester);
    await query(tester, 'alpha');
    await query(tester, 'beta');
    repository.requests['beta']!.complete([_result('beta result')]);
    await tester.pumpAndSettle();
    repository.requests['alpha']!.complete([_result('alpha result')]);
    await tester.pumpAndSettle();
    expect(find.text('beta result'), findsOneWidget);
    expect(find.text('alpha result'), findsNothing);
  });

  testWidgets('clear immediately stops loading and ignores a pending error',
      (tester) async {
    final _SearchRepository repository = await pumpSearch(tester);
    await query(tester, 'alpha');
    await tester.tap(find.byTooltip(AppStrings.clearSearch));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    repository.requests['alpha']!.completeError(StateError('old request'));
    await tester.pumpAndSettle();
    expect(find.textContaining('old request'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('clear cancels the debounced request', (tester) async {
    final _SearchRepository repository = await pumpSearch(tester);
    await tester.enterText(
        find.byKey(const ValueKey<String>('message-search')), 'alpha');
    await tester.pump();
    await tester.tap(find.byTooltip(AppStrings.clearSearch));
    await tester.pump(const Duration(milliseconds: 350));
    expect(repository.requests, isEmpty);
  });
}
