import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cch3r1_messanger/config/theme.dart';
import 'package:cch3r1_messanger/core/constants/app_strings.dart';
import 'package:cch3r1_messanger/core/providers/supabase_providers.dart';
import 'package:cch3r1_messanger/features/auth/domain/entities/profile_entity.dart';
import 'package:cch3r1_messanger/features/chat_list/domain/entities/conversation_entity.dart';
import 'package:cch3r1_messanger/features/chat_list/presentation/providers/chat_list_providers.dart';
import 'package:cch3r1_messanger/features/chat_list/presentation/screens/chat_list_screen.dart';
import 'package:cch3r1_messanger/features/chat_list/presentation/utils/conversation_filter.dart';
import 'package:cch3r1_messanger/services/connection_service.dart';

List<ConversationEntity> _conversations({bool longName = false}) => [
      ConversationEntity(
          id: 'alina',
          kind: ConversationKind.dm,
          updatedAt: DateTime(2026, 9, 14),
          members: const [],
          unreadCount: 2,
          peer: ProfileEntity(
              id: 'alina',
              username: 'alina',
              displayName: longName
                  ? 'Очень длинное отображаемое имя собеседника'
                  : 'Алина',
              rank: longName ? 'ОЧЕНЬ ДЛИННЫЙ СТАТУС' : null)),
      ConversationEntity(
          id: 'max',
          kind: ConversationKind.dm,
          updatedAt: DateTime(2026, 9, 14),
          members: const [],
          peer: const ProfileEntity(
              id: 'max', username: 'max_orlov', displayName: 'Максим')),
      ConversationEntity(
          id: 'group',
          kind: ConversationKind.group,
          updatedAt: DateTime(2026, 9, 14),
          members: const [],
          title: 'Дизайн-команда'),
    ];

class _InboxController extends ChatListController {
  _InboxController(this.items);
  final List<ConversationEntity> items;
  int refreshes = 0;

  @override
  Future<List<ConversationEntity>> build() async => items;

  void loading() => state =
      const AsyncLoading<List<ConversationEntity>>().copyWithPrevious(state);

  void failRefresh() => state = AsyncError<List<ConversationEntity>>(
          StateError('offline'), StackTrace.current)
      .copyWithPrevious(state);

  @override
  Future<void> refresh() async {
    refreshes++;
    state = AsyncData<List<ConversationEntity>>(items);
  }
}

Future<void> _pump(WidgetTester tester, _InboxController controller,
    {Size size = const Size(390, 844),
    bool dark = false,
    bool offline = false,
    double textScale = 1,
    double keyboard = 0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      chatListControllerProvider.overrideWith(() => controller),
      currentUserIdProvider.overrideWithValue('self'),
      connectivityProvider.overrideWith((_) => Stream<bool>.value(!offline)),
    ],
    child: MaterialApp(
      theme: dark ? AppTheme.dark(null) : AppTheme.light(null),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
      home: const ChatListScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  testWidgets('local search, empty result and reset retain all conversations',
      (tester) async {
    final _InboxController controller = _InboxController(_conversations());
    await _pump(tester, controller);
    final Finder search = find.byKey(const ValueKey<String>('inbox-search'));
    await tester.enterText(search, ' @MAX_ORLOV ');
    await tester.pumpAndSettle();
    expect(find.text('Максим'), findsOneWidget);
    expect(find.text('Алина'), findsNothing);
    await tester.enterText(search, 'unknown');
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.inboxNoResults), findsOneWidget);
    await tester.tap(find.text(AppStrings.resetFilters));
    await tester.pumpAndSettle();
    expect(find.text('Алина'), findsOneWidget);
    expect(find.text('Максим'), findsOneWidget);
    expect(controller.refreshes, 0);
  });

  testWidgets('unread and group filters show the correct subset',
      (tester) async {
    await _pump(tester, _InboxController(_conversations()));
    await tester.tap(find
        .byKey(const ValueKey<ConversationFilter>(ConversationFilter.unread)));
    await tester.pumpAndSettle();
    expect(find.text('Алина'), findsOneWidget);
    expect(find.text('Максим'), findsNothing);
    final Finder groups = find
        .byKey(const ValueKey<ConversationFilter>(ConversationFilter.groups));
    await tester.ensureVisible(groups);
    await tester.tap(groups);
    await tester.pumpAndSettle();
    expect(find.text('Дизайн-команда'), findsOneWidget);
    expect(find.text('Алина'), findsNothing);
  });

  testWidgets('refresh loading and errors keep the previous list visible',
      (tester) async {
    final _InboxController controller = _InboxController(_conversations());
    await _pump(tester, controller);
    controller.loading();
    await tester.pump();
    expect(find.text('Алина'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    controller.failRefresh();
    await tester.pumpAndSettle();
    expect(find.text('Алина'), findsOneWidget);
    expect(find.text(AppStrings.inboxRefreshError), findsOneWidget);
    await tester.tap(find.byTooltip(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(controller.refreshes, 1);
    expect(find.text(AppStrings.inboxRefreshError), findsNothing);
  });

  testWidgets('empty list supports pull-to-refresh', (tester) async {
    final _InboxController controller = _InboxController([]);
    await _pump(tester, controller);
    expect(find.text(AppStrings.chatsEmpty), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(controller.refreshes, 1);
  });

  testWidgets('offline mode keeps cached conversations available',
      (tester) async {
    await _pump(tester, _InboxController(_conversations()), offline: true);
    expect(find.text(AppStrings.inboxOfflineHint), findsOneWidget);
    expect(find.text('Алина'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final bool dark in [false, true]) {
    for (final double width in [320, 1024]) {
      testWidgets(
          'responsive layout, large text and keyboard: dark=$dark, width=$width',
          (tester) async {
        await _pump(tester, _InboxController(_conversations(longName: true)),
            size: Size(width, 640), dark: dark, textScale: 2, keyboard: 260);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(NestedScrollView), const Offset(0, -400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
