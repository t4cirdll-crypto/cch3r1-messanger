import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cch3r1_messanger/core/providers/supabase_providers.dart';
import 'package:cch3r1_messanger/features/chat_list/domain/entities/conversation_entity.dart';
import 'package:cch3r1_messanger/features/chat_list/domain/repositories/chat_list_repository.dart';
import 'package:cch3r1_messanger/features/chat_list/presentation/providers/chat_list_providers.dart';

final _accountProvider = StateProvider<String?>((_) => 'A');

ConversationEntity _conversation(String id) => ConversationEntity(
    id: id,
    kind: ConversationKind.group,
    title: id,
    updatedAt: DateTime(2026),
    members: const []);

class _Repository implements ChatListRepository {
  final StreamController<void> events = StreamController<void>.broadcast();
  final List<Completer<List<ConversationEntity>>> pending = [];
  bool hold = false;
  int calls = 0;
  int active = 0;
  int peak = 0;

  @override
  Future<List<ConversationEntity>> getConversations() {
    calls++;
    if (!hold) return Future.value([_conversation('A')]);
    final Completer<List<ConversationEntity>> request =
        Completer<List<ConversationEntity>>();
    pending.add(request);
    active++;
    if (active > peak) peak = active;
    return request.future.whenComplete(() => active--);
  }

  @override
  Stream<void> watchConversationChanges() => events.stream;

  void burst() {
    for (int i = 0; i < 50; i++) {
      events.add(null);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<({ProviderContainer container, _Repository repo})> setup() async {
    final _Repository repo = _Repository();
    final ProviderContainer container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(_accountProvider)),
      chatListRepositoryProvider.overrideWith((_) async => repo),
    ]);
    final subscription =
        container.listen(chatListControllerProvider, (_, __) {});
    addTearDown(() async {
      subscription.close();
      container.dispose();
      await repo.events.close();
    });
    await container.read(chatListControllerProvider.future);
    return (container: container, repo: repo);
  }

  testWidgets(
      'concurrent refresh calls join one request and retain visible data',
      (tester) async {
    final fixture = await setup();
    final container = fixture.container;
    final repo = fixture.repo..hold = true;
    final controller = container.read(chatListControllerProvider.notifier);
    final Future<void> first = controller.refresh();
    final Future<void> second = controller.refresh();
    await tester.pump();
    expect(identical(first, second), isTrue);
    expect(repo.calls, 2);
    expect(
        container.read(chatListControllerProvider).valueOrNull!.single.id, 'A');
    repo.pending.single.complete([_conversation('updated')]);
    await first;
    expect(container.read(chatListControllerProvider).valueOrNull!.single.id,
        'updated');
  });

  testWidgets(
      '50 realtime events coalesce; events during fetch get one trailing request',
      (tester) async {
    final fixture = await setup();
    final repo = fixture.repo..hold = true;
    repo.burst();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 251));
    expect(repo.calls, 2);
    repo.burst();
    await tester.pump();
    repo.pending.first.complete([_conversation('snapshot')]);
    await tester.pump();
    expect(repo.calls, 3);
    expect(repo.peak, 1);
    repo.pending.last.complete([_conversation('latest')]);
    await tester.pump();
    expect(
        fixture.container
            .read(chatListControllerProvider)
            .valueOrNull!
            .single
            .id,
        'latest');
  });

  testWidgets('failed background refresh preserves data and can be retried',
      (tester) async {
    final fixture = await setup();
    final repo = fixture.repo..hold = true;
    final controller =
        fixture.container.read(chatListControllerProvider.notifier);
    final Future<void> refresh = controller.refresh();
    await tester.pump();
    repo.pending.single.completeError(StateError('offline'));
    await refresh;
    final state = fixture.container.read(chatListControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.valueOrNull!.single.id, 'A');
    repo.hold = false;
    await controller.refresh();
    expect(
        fixture.container.read(chatListControllerProvider).hasError, isFalse);
  });

  testWidgets(
      'account switch clears previous data and ignores old in-flight results',
      (tester) async {
    final fixture = await setup();
    final container = fixture.container;
    final repo = fixture.repo..hold = true;
    final Future<void> old =
        container.read(chatListControllerProvider.notifier).refresh();
    await tester.pump();
    container.read(_accountProvider.notifier).state = 'B';
    expect(
        container.read(chatListControllerProvider).valueOrNull ?? [], isEmpty);
    await tester.pump();
    repo.pending.last.complete([_conversation('B')]);
    await tester.pump();
    repo.pending.first.complete([_conversation('private-A')]);
    await old;
    expect(
        container.read(chatListControllerProvider).valueOrNull!.single.id, 'B');
    container.read(_accountProvider.notifier).state = null;
    await tester.pump();
    expect(container.read(chatListControllerProvider).valueOrNull, isEmpty);
  });

  testWidgets('dispose cancels scheduled realtime refreshes', (tester) async {
    final fixture = await setup();
    fixture.repo.burst();
    await tester.pump();
    fixture.container.dispose();
    await tester.pump(const Duration(milliseconds: 500));
    expect(fixture.repo.calls, 1);
    expect(fixture.repo.events.hasListener, isFalse);
    expect(tester.takeException(), isNull);
  });
}
