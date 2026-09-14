import 'dart:async';

import 'package:cch3r1_messanger/core/providers/supabase_providers.dart';
import 'package:cch3r1_messanger/features/chat/domain/entities/message_entity.dart';
import 'package:cch3r1_messanger/features/chat/domain/repositories/chat_repository.dart';
import 'package:cch3r1_messanger/features/chat/presentation/providers/chat_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const String _conversationId = 'conversation-1';
final DateTime _origin = DateTime.utc(2025, 1, 1, 12);

void main() {
  group('ChatController', () {
    test('disposes realtime subscriptions after the last listener leaves',
        () async {
      final _FakeChatRepository repository = _FakeChatRepository(
        initialMessages: <MessageEntity>[_message('current', 2)],
      );
      final _ChatHarness harness = await _startChat(repository);
      addTearDown(harness.dispose);

      harness.removeListener();
      await _flushAutoDispose();

      expect(repository.messageSubscriptionCancels, 1);
      expect(repository.reactionSubscriptionCancels, 1);
      expect(repository.deleteSubscriptionCancels, 1);
    });

    test('clears messages and subscriptions when the user signs out', () async {
      final _FakeChatRepository repository = _FakeChatRepository(
        initialMessages: <MessageEntity>[_message('user-a-message', 2)],
      );
      final _ChatHarness harness = await _startChat(repository);
      addTearDown(harness.dispose);

      harness.setCurrentUserId(null);
      await _flushAutoDispose();
      final ChatState signedOut = harness.state;

      expect(signedOut.messages, isEmpty);
      expect(signedOut.hasMore, isFalse);
      expect(repository.initialLoadRequests, 1);
      expect(repository.messageSubscriptionCancels, 1);
      expect(repository.reactionSubscriptionCancels, 1);
      expect(repository.deleteSubscriptionCancels, 1);
    });

    test('clears prior account messages while the next account is loading',
        () async {
      final _FakeChatRepository repository = _FakeChatRepository(
        initialMessages: <MessageEntity>[_message('user-a-message', 2)],
      );
      final _ChatHarness harness = await _startChat(repository);
      addTearDown(harness.dispose);

      repository.initialMessages = <MessageEntity>[
        _message('user-b-message', 3),
      ];
      repository
        ..initialPage = Completer<List<MessageEntity>>()
        ..initialLoadStarted = Completer<void>();
      harness.setCurrentUserId('user-b');
      await repository.initialLoadStarted!.future;

      final AsyncValue<ChatState> switchingState = harness.asyncState;
      expect(switchingState.isLoading, isTrue);
      expect(switchingState.valueOrNull?.messages, isEmpty);
      expect(switchingState.valueOrNull?.hasMore, isFalse);
      expect(repository.messageSubscriptionCancels, 1);
      expect(repository.reactionSubscriptionCancels, 1);
      expect(repository.deleteSubscriptionCancels, 1);

      final Future<ChatState> userB = harness.waitForState(
        (ChatState state) => state.messages
            .any((MessageEntity message) => message.id == 'user-b-message'),
      );
      repository.initialPage!.complete(repository.initialMessages);
      final ChatState loadedUserB = await userB;

      expect(
        loadedUserB.messages
            .map((MessageEntity message) => message.id)
            .toList(),
        <String>['user-b-message'],
      );
      expect(repository.initialLoadRequests, 2);
    });

    test('sendMessage reports that the chat is still loading', () async {
      final _FakeChatRepository repository = _FakeChatRepository(
        initialMessages: <MessageEntity>[_message('current', 2)],
      )
        ..initialPage = Completer<List<MessageEntity>>()
        ..initialLoadStarted = Completer<void>();
      final _ChatHarness harness =
          await _startChat(repository, waitForInitialLoad: false);
      addTearDown(harness.dispose);
      await repository.initialLoadStarted!.future;

      await expectLater(
        harness.controller.sendMessage('Draft message'),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.toString(),
            'message',
            contains('Чат ещё загружается'),
          ),
        ),
      );
      expect(repository.sendStarted.isCompleted, isFalse);

      repository.initialPage!.complete(repository.initialMessages);
      await harness.waitForState(
        (ChatState state) => state.messages.isNotEmpty,
      );
    });

    test('loadMore keeps messages received while the page is loading',
        () async {
      final _FakeChatRepository repository = _FakeChatRepository(
        initialMessages: _fullPage(),
      )..olderPage = Completer<List<MessageEntity>>();
      final _ChatHarness harness = await _startChat(repository);
      addTearDown(harness.dispose);

      final ChatController controller = harness.controller;
      final Future<void> loading = controller.loadMore();
      await repository.loadMoreStarted.future;

      repository.emitMessage(_message('realtime', 32));
      repository.olderPage!.complete(<MessageEntity>[_message('older', 1)]);
      await loading;

      expect(harness.messageIds, <String>[
        'older',
        ...List<String>.generate(30, (int index) => 'current-${index + 2}'),
        'realtime',
      ]);
      expect(harness.state.isLoadingMore, isFalse);
    });

    test('sendMessage keeps messages received before the send completes',
        () async {
      final _FakeChatRepository repository = _FakeChatRepository(
        initialMessages: <MessageEntity>[_message('current', 2)],
      )..sendResponse = Completer<MessageEntity>();
      final _ChatHarness harness = await _startChat(repository);
      addTearDown(harness.dispose);

      final Future<void> sending = harness.controller.sendMessage('Sent');
      await repository.sendStarted.future;

      repository.emitMessage(_message('realtime', 3));
      repository.sendResponse!.complete(_message('sent', 4, content: 'Sent'));
      await sending;

      expect(harness.messageIds, <String>['current', 'realtime', 'sent']);
    });

    test('editMessage keeps messages received before the edit completes',
        () async {
      final _FakeChatRepository repository = _FakeChatRepository(
        initialMessages: <MessageEntity>[_message('current', 2)],
      )..editResponse = Completer<void>();
      final _ChatHarness harness = await _startChat(repository);
      addTearDown(harness.dispose);

      final Future<void> editing =
          harness.controller.editMessage('current', 'Updated');
      await repository.editStarted.future;

      repository.emitMessage(_message('realtime', 3));
      repository.editResponse!.complete();
      await editing;

      expect(harness.messageIds, <String>['current', 'realtime']);
      expect(harness.message('current').content, 'Updated');
    });

    test('delete for all keeps messages received before the delete completes',
        () async {
      final MessageEntity current = _messageWithReplyAndReactions('current', 2);
      final _FakeChatRepository repository = _FakeChatRepository(
        initialMessages: <MessageEntity>[current],
      )..deleteForAllResponse = Completer<void>();
      final _ChatHarness harness = await _startChat(repository);
      addTearDown(harness.dispose);

      final Future<void> deleting =
          harness.controller.deleteMessage('current', forAll: true);
      await repository.deleteForAllStarted.future;

      repository.emitMessage(_message('realtime', 3));
      repository.deleteForAllResponse!.complete();
      await deleting;

      expect(harness.messageIds, <String>['current', 'realtime']);
      final MessageEntity deleted = harness.message('current');
      expect(deleted.isDeleted, isTrue);
      expect(deleted.content, '');
      expect(deleted.replyToId, isNull);
      expect(deleted.replyTo, isNull);
      expect(deleted.reactions, isEmpty);
    });

    test('deleted realtime updates clear prior replies and reactions',
        () async {
      final MessageEntity current = _messageWithReplyAndReactions('current', 2);
      final _FakeChatRepository repository = _FakeChatRepository(
        initialMessages: <MessageEntity>[current],
      );
      final _ChatHarness harness = await _startChat(repository);
      addTearDown(harness.dispose);

      repository.emitMessage(MessageEntity(
        id: current.id,
        conversationId: current.conversationId,
        senderId: current.senderId,
        content: '',
        createdAt: current.createdAt,
        deletedAt: _origin.add(const Duration(minutes: 3)),
      ));

      final MessageEntity deleted = harness.message('current');
      expect(deleted.isDeleted, isTrue);
      expect(deleted.replyToId, isNull);
      expect(deleted.replyTo, isNull);
      expect(deleted.reactions, isEmpty);
    });

    test('delete for me keeps messages received before the delete completes',
        () async {
      final _FakeChatRepository repository = _FakeChatRepository(
        initialMessages: <MessageEntity>[_message('current', 2)],
      )..deleteForMeResponse = Completer<void>();
      final _ChatHarness harness = await _startChat(repository);
      addTearDown(harness.dispose);

      final Future<void> deleting =
          harness.controller.deleteMessage('current', forAll: false);
      await repository.deleteForMeStarted.future;

      repository.emitMessage(_message('realtime', 3));
      repository.deleteForMeResponse!.complete();
      await deleting;

      expect(harness.messageIds, <String>['realtime']);
    });

    test('togglePin keeps messages received before the update completes',
        () async {
      final _FakeChatRepository repository = _FakeChatRepository(
        initialMessages: <MessageEntity>[_message('current', 2)],
      )..pinResponse = Completer<void>();
      final _ChatHarness harness = await _startChat(repository);
      addTearDown(harness.dispose);

      final Future<void> pinning = harness.controller.togglePin('current');
      await repository.pinStarted.future;

      repository.emitMessage(_message('realtime', 3));
      repository.pinResponse!.complete();
      await pinning;

      expect(harness.messageIds, <String>['current', 'realtime']);
      expect(harness.message('current').isPinned, isTrue);
    });
  });
}

MessageEntity _message(String id, int minute, {String? content}) {
  return MessageEntity(
    id: id,
    conversationId: _conversationId,
    senderId: 'sender-$id',
    content: content ?? id,
    createdAt: _origin.add(Duration(minutes: minute)),
  );
}

MessageEntity _messageWithReplyAndReactions(String id, int minute) {
  final MessageEntity reply = _message('$id-reply', minute - 1);
  return _message(id, minute, content: 'Sensitive message').copyWith(
    replyToId: reply.id,
    replyTo: reply,
    reactions: <ReactionEntity>[
      const ReactionEntity(emoji: '👍', userIds: <String>['user-a']),
    ],
  );
}

List<MessageEntity> _fullPage() {
  return List<MessageEntity>.generate(
    30,
    (int index) => _message('current-${31 - index}', 31 - index),
  );
}

Future<void> _flushAutoDispose() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<_ChatHarness> _startChat(
  _FakeChatRepository repository, {
  bool waitForInitialLoad = true,
}) async {
  final StateProvider<String?> userIdProvider =
      StateProvider<String?>((_) => 'user-a');
  final ProviderContainer container = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWith(
        (Ref ref) => ref.watch(userIdProvider),
      ),
      chatRepositoryProvider.overrideWith((_) async => repository),
    ],
  );
  final ProviderSubscription<AsyncValue<ChatState>> subscription =
      container.listen<AsyncValue<ChatState>>(
    chatControllerProvider(_conversationId),
    (AsyncValue<ChatState>? previous, AsyncValue<ChatState> next) {},
  );
  container.read(chatControllerProvider(_conversationId));
  if (waitForInitialLoad) {
    await container.read(chatControllerProvider(_conversationId).future);
  }
  return _ChatHarness(repository, container, subscription, userIdProvider);
}

class _ChatHarness {
  _ChatHarness(
    this.repository,
    this.container,
    this._subscription,
    this._userIdProvider,
  );

  final _FakeChatRepository repository;
  final ProviderContainer container;
  final ProviderSubscription<AsyncValue<ChatState>> _subscription;
  final StateProvider<String?> _userIdProvider;
  bool _listenerRemoved = false;
  bool _disposed = false;

  ChatController get controller =>
      container.read(chatControllerProvider(_conversationId).notifier);

  ChatState get state =>
      container.read(chatControllerProvider(_conversationId)).valueOrNull!;

  AsyncValue<ChatState> get asyncState =>
      container.read(chatControllerProvider(_conversationId));

  List<String> get messageIds =>
      state.messages.map((MessageEntity message) => message.id).toList();

  MessageEntity message(String id) =>
      state.messages.firstWhere((MessageEntity message) => message.id == id);

  void removeListener() {
    if (_listenerRemoved) return;
    _listenerRemoved = true;
    _subscription.close();
  }

  void setCurrentUserId(String? userId) {
    container.read(_userIdProvider.notifier).state = userId;
  }

  Future<ChatState> waitForState(bool Function(ChatState state) predicate) {
    final ChatState? current =
        container.read(chatControllerProvider(_conversationId)).valueOrNull;
    if (current != null && predicate(current)) {
      return Future<ChatState>.value(current);
    }

    final Completer<ChatState> result = Completer<ChatState>();
    late final ProviderSubscription<AsyncValue<ChatState>> subscription;
    subscription = container.listen<AsyncValue<ChatState>>(
      chatControllerProvider(_conversationId),
      (AsyncValue<ChatState>? previous, AsyncValue<ChatState> next) {
        final ChatState? value = next.valueOrNull;
        if (value == null || !predicate(value) || result.isCompleted) return;
        result.complete(value);
        subscription.close();
      },
    );
    return result.future;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    removeListener();
    container.dispose();
    await repository.dispose();
  }
}

class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({required this.initialMessages});

  List<MessageEntity> initialMessages;
  int initialLoadRequests = 0;
  Completer<void>? initialLoadStarted;
  Completer<List<MessageEntity>>? initialPage;

  late final StreamController<MessageEntity> _messages =
      StreamController<MessageEntity>.broadcast(
    sync: true,
    onCancel: () => messageSubscriptionCancels += 1,
  );
  late final StreamController<ReactionDelta> _reactions =
      StreamController<ReactionDelta>.broadcast(
    sync: true,
    onCancel: () => reactionSubscriptionCancels += 1,
  );
  late final StreamController<String> _deletes =
      StreamController<String>.broadcast(
    sync: true,
    onCancel: () => deleteSubscriptionCancels += 1,
  );

  int messageSubscriptionCancels = 0;
  int reactionSubscriptionCancels = 0;
  int deleteSubscriptionCancels = 0;

  Completer<List<MessageEntity>>? olderPage;
  Completer<MessageEntity>? sendResponse;
  Completer<void>? editResponse;
  Completer<void>? deleteForAllResponse;
  Completer<void>? deleteForMeResponse;
  Completer<void>? pinResponse;

  final Completer<void> loadMoreStarted = Completer<void>();
  final Completer<void> sendStarted = Completer<void>();
  final Completer<void> editStarted = Completer<void>();
  final Completer<void> deleteForAllStarted = Completer<void>();
  final Completer<void> deleteForMeStarted = Completer<void>();
  final Completer<void> pinStarted = Completer<void>();

  void emitMessage(MessageEntity message) => _messages.add(message);

  Future<void> dispose() async {
    await _messages.close();
    await _reactions.close();
    await _deletes.close();
  }

  @override
  Future<void> deleteForAll(String messageId) {
    if (!deleteForAllStarted.isCompleted) deleteForAllStarted.complete();
    return deleteForAllResponse?.future ?? Future<void>.value();
  }

  @override
  Future<void> deleteForMe(String messageId) {
    if (!deleteForMeStarted.isCompleted) deleteForMeStarted.complete();
    return deleteForMeResponse?.future ?? Future<void>.value();
  }

  @override
  Future<void> editMessage({
    required String messageId,
    required String content,
  }) {
    if (!editStarted.isCompleted) editStarted.complete();
    return editResponse?.future ?? Future<void>.value();
  }

  @override
  Future<String> getAttachmentSignedUrl(String storagePath) async =>
      storagePath;

  @override
  Future<List<MessageEntity>> getMessages(
    String conversationId, {
    int limit = 30,
    DateTime? before,
  }) {
    if (before == null) {
      initialLoadRequests += 1;
      final Completer<void>? started = initialLoadStarted;
      if (started != null && !started.isCompleted) started.complete();
      return initialPage?.future ??
          Future<List<MessageEntity>>.value(initialMessages);
    }
    if (!loadMoreStarted.isCompleted) loadMoreStarted.complete();
    return olderPage?.future ??
        Future<List<MessageEntity>>.value(<MessageEntity>[]);
  }

  @override
  Future<List<MessageEntity>> getPinnedMessages(String conversationId) async =>
      <MessageEntity>[];

  @override
  Future<void> markAsRead(String conversationId) async {}

  @override
  Future<List<MessageEntity>> searchInConversation({
    required String conversationId,
    required String query,
  }) async =>
      <MessageEntity>[];

  @override
  Future<MessageEntity> sendMessage({
    required String conversationId,
    String? content,
    OutgoingAttachment? attachment,
    String? replyToId,
    String? forwardedFromMessageId,
    String? forwardedFromSenderId,
  }) {
    if (!sendStarted.isCompleted) sendStarted.complete();
    return sendResponse?.future ??
        Future<MessageEntity>.value(_message('sent', 4, content: content));
  }

  @override
  Future<void> setPin({required String messageId, required bool pinned}) {
    if (!pinStarted.isCompleted) pinStarted.complete();
    return pinResponse?.future ?? Future<void>.value();
  }

  @override
  Future<int> sweepExpiredMessages() async => 0;

  @override
  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {}

  @override
  Stream<String> watchMessageDeletes(String conversationId) => _deletes.stream;

  @override
  Stream<MessageEntity> watchMessages(String conversationId) =>
      _messages.stream;

  @override
  Stream<ReactionDelta> watchReactions() => _reactions.stream;
}
