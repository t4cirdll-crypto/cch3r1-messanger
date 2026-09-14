import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cch3r1_messanger/config/theme.dart';
import 'package:cch3r1_messanger/core/providers/supabase_providers.dart';
import 'package:cch3r1_messanger/core/services/notifications_listener.dart';
import 'package:cch3r1_messanger/core/utils/drafts_manager.dart';
import 'package:cch3r1_messanger/features/chat/presentation/providers/chat_providers.dart';
import 'package:cch3r1_messanger/features/chat/presentation/screens/chat_screen.dart';
import 'package:cch3r1_messanger/features/chat_list/presentation/providers/chat_list_providers.dart';

import '../../../tool/preview_data.dart';

void main() {
  const String conversationId = 'preview-alina-chat';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await DraftsManager.init();
    await initializeDateFormatting('ru');
  });

  Future<ProviderContainer> pumpChat(WidgetTester tester) async {
    await DraftsManager.clearDraft(conversationId, accountId: previewUserId);
    final PreviewStore store = PreviewStore();
    final ProviderContainer container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue(previewUserId),
      supabaseClientProvider
          .overrideWith((_) => throw StateError('No live backend in tests')),
      chatListRepositoryProvider.overrideWith((_) async => store),
      chatRepositoryProvider.overrideWith((_) async => store),
      typingChannelProvider.overrideWith((_, __) => PreviewTypingChannel()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          theme: AppTheme.light(null),
          home: ChatScreen(
            conversationId: conversationId,
            conversation: store.conversation(conversationId),
          )),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('draft writes are debounced and the final text is saved on exit',
      (tester) async {
    final ProviderContainer container = await pumpChat(tester);
    final Finder composer = find.byType(TextField);
    await tester.enterText(composer, 'Пр');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(composer, 'Привет');
    await tester.pump(const Duration(milliseconds: 100));
    expect(DraftsManager.getDraft(conversationId, accountId: previewUserId),
        isNull);
    await tester.pump(const Duration(milliseconds: 150));
    expect(DraftsManager.getDraft(conversationId, accountId: previewUserId),
        'Привет');

    await tester.enterText(composer, 'Привет, до завтра!');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(DraftsManager.getDraft(conversationId, accountId: previewUserId),
        'Привет, до завтра!');
    expect(container.read(activeConversationIdProvider), isNull);
    container.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening and closing a chat releases its active conversation',
      (tester) async {
    final ProviderContainer container = await pumpChat(tester);
    expect(container.read(activeConversationIdProvider), conversationId);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(activeConversationIdProvider), isNull);
    container.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
