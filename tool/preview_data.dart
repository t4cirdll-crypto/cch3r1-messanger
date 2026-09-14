import 'dart:async';

import 'package:cch3r1_messanger/features/auth/domain/entities/profile_entity.dart';
import 'package:cch3r1_messanger/features/chat/data/services/typing_service.dart';
import 'package:cch3r1_messanger/features/chat/domain/entities/message_entity.dart';
import 'package:cch3r1_messanger/features/chat/domain/repositories/chat_repository.dart';
import 'package:cch3r1_messanger/features/chat_list/domain/entities/conversation_entity.dart';
import 'package:cch3r1_messanger/features/chat_list/domain/repositories/chat_list_repository.dart';

const String previewUserId = 'preview-self';
const List<ProfileEntity> previewPeople = <ProfileEntity>[
  ProfileEntity(
      id: 'preview-alina',
      username: 'alina',
      displayName: 'Алина Волкова',
      isOnline: true),
  ProfileEntity(
      id: 'preview-max', username: 'max_orlov', displayName: 'Максим Орлов'),
  ProfileEntity(
      id: 'preview-sonya',
      username: 'sonya_k',
      displayName: 'Соня Ким',
      isOnline: true),
  ProfileEntity(
      id: 'preview-ilya', username: 'ilya', displayName: 'Илья Смирнов'),
];

/// In-memory repositories for the separate preview entrypoint, never production.
class PreviewStore implements ChatListRepository, ChatRepository {
  PreviewStore() {
    reset();
  }

  final StreamController<void> _changes = StreamController<void>.broadcast();
  final StreamController<MessageEntity> _incoming =
      StreamController<MessageEntity>.broadcast();
  final StreamController<String> _deleted =
      StreamController<String>.broadcast();
  final Map<String, List<MessageEntity>> _messages =
      <String, List<MessageEntity>>{};
  final List<ConversationEntity> _conversations = <ConversationEntity>[];
  int _sequence = 0;

  void reset() {
    _messages.clear();
    _conversations.clear();
    final DateTime now = DateTime.now();
    final List<
        ({
          String id,
          String? title,
          ConversationKind kind,
          ProfileEntity? peer,
          String text,
          int unread,
          bool muted,
          bool mine
        })> seed = [
      (
        id: 'preview-alina-chat',
        title: null,
        kind: ConversationKind.dm,
        peer: previewPeople[0],
        text: 'А как тебе такой вариант?',
        unread: 2,
        muted: false,
        mine: false
      ),
      (
        id: 'preview-design',
        title: 'Дизайн-команда',
        kind: ConversationKind.group,
        peer: null,
        text: 'Полина: Собрала всё в одном файле ✨',
        unread: 5,
        muted: false,
        mine: false
      ),
      (
        id: 'preview-saved',
        title: null,
        kind: ConversationKind.saved,
        peer: null,
        text: 'Идеи, ссылки и всё самое важное',
        unread: 0,
        muted: false,
        mine: true
      ),
      (
        id: 'preview-max-chat',
        title: null,
        kind: ConversationKind.dm,
        peer: previewPeople[1],
        text: 'Отлично, до вечера!',
        unread: 0,
        muted: false,
        mine: true
      ),
      (
        id: 'preview-north',
        title: 'Проект «Север»',
        kind: ConversationKind.group,
        peer: null,
        text: 'Антон: Встречаемся завтра в 10:00',
        unread: 12,
        muted: true,
        mine: false
      ),
      (
        id: 'preview-sonya-chat',
        title: null,
        kind: ConversationKind.dm,
        peer: previewPeople[2],
        text: 'Спасибо! Получилось очень красиво 💜',
        unread: 0,
        muted: false,
        mine: false
      ),
      (
        id: 'preview-ilya-chat',
        title: null,
        kind: ConversationKind.dm,
        peer: previewPeople[3],
        text: 'Давай обсудим на выходных',
        unread: 0,
        muted: false,
        mine: false
      ),
    ];
    for (int i = 0; i < seed.length; i++) {
      final item = seed[i];
      final DateTime at = now.subtract(Duration(minutes: 5 + i * 35));
      final String peerId = item.peer?.id ?? 'preview-teammate';
      final List<MessageEntity> messages = <MessageEntity>[
        MessageEntity(
            id: '${item.id}-1',
            conversationId: item.id,
            senderId: peerId,
            createdAt: at.subtract(const Duration(minutes: 10)),
            content: 'Привет! Есть минутка обсудить идеи?'),
        MessageEntity(
            id: '${item.id}-2',
            conversationId: item.id,
            senderId: previewUserId,
            createdAt: at.subtract(const Duration(minutes: 8)),
            content: 'Конечно! Мне нравится, когда всё просто и понятно.',
            isRead: true),
        MessageEntity(
            id: '${item.id}-3',
            conversationId: item.id,
            senderId: peerId,
            createdAt: at.subtract(const Duration(minutes: 4)),
            content: 'Тогда оставим самое важное. Без лишних деталей.'),
        MessageEntity(
            id: '${item.id}-4',
            conversationId: item.id,
            senderId: item.mine ? previewUserId : peerId,
            createdAt: at,
            content: item.text,
            isRead: item.mine),
      ];
      _messages[item.id] = messages;
      _conversations.add(ConversationEntity(
          id: item.id,
          kind: item.kind,
          updatedAt: at,
          members: const <ConversationMember>[],
          title: item.title,
          peer: item.peer,
          lastMessage: messages.last,
          unreadCount: item.unread,
          muted: item.muted));
    }
    _changes.add(null);
  }

  ConversationEntity conversation(String id) =>
      _conversations.firstWhere((ConversationEntity c) => c.id == id);

  @override
  Future<List<ConversationEntity>> getConversations() async =>
      List<ConversationEntity>.of(_conversations)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Stream<void> watchConversationChanges() => _changes.stream;

  @override
  Future<ConversationEntity> createOrGetSaved() async =>
      conversation('preview-saved');

  @override
  Future<ConversationEntity> createOrGetDm(String peerId) async =>
      _conversations.firstWhere((ConversationEntity c) => c.peer?.id == peerId);

  @override
  Future<void> markRead(String conversationId) async {
    final int index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index < 0 || _conversations[index].unreadCount == 0) return;
    _conversations[index] = _conversations[index].copyWith(unreadCount: 0);
    _changes.add(null);
  }

  @override
  Future<void> markAsRead(String conversationId) => markRead(conversationId);

  @override
  Future<List<MessageEntity>> getMessages(String conversationId,
      {int limit = 30, DateTime? before}) async {
    final List<MessageEntity> messages = (_messages[conversationId] ?? [])
        .where((m) => before == null || m.createdAt.isBefore(before))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return messages.take(limit).toList();
  }

  @override
  Future<MessageEntity> sendMessage(
      {required String conversationId,
      String? content,
      OutgoingAttachment? attachment,
      String? replyToId,
      String? forwardedFromMessageId,
      String? forwardedFromSenderId}) async {
    if (attachment != null) {
      throw UnsupportedError('В превью доступны текстовые сообщения');
    }
    final MessageEntity message = MessageEntity(
      id: 'preview-sent-${++_sequence}',
      conversationId: conversationId,
      senderId: previewUserId,
      createdAt: DateTime.now(),
      content: content,
      replyToId: replyToId,
      forwardedFromMessageId: forwardedFromMessageId,
      forwardedFromSenderId: forwardedFromSenderId,
    );
    _messages.putIfAbsent(conversationId, () => []).add(message);
    final int index = _conversations.indexWhere((c) => c.id == conversationId);
    _conversations[index] = _conversations[index]
        .copyWith(lastMessage: message, updatedAt: message.createdAt);
    _incoming.add(message);
    _changes.add(null);
    return message;
  }

  void _update(String id, MessageEntity Function(MessageEntity) update) {
    for (final List<MessageEntity> messages in _messages.values) {
      final int index = messages.indexWhere((m) => m.id == id);
      if (index < 0) continue;
      final MessageEntity updated = update(messages[index]);
      messages[index] = updated;
      for (int i = 0; i < _conversations.length; i++) {
        if (_conversations[i].lastMessage?.id == id) {
          _conversations[i] = _conversations[i].copyWith(lastMessage: updated);
        }
      }
      _incoming.add(updated);
      _changes.add(null);
      return;
    }
  }

  @override
  Future<void> editMessage(
          {required String messageId, required String content}) async =>
      _update(messageId,
          (m) => m.copyWith(content: content, editedAt: DateTime.now()));

  @override
  Future<void> deleteForAll(String messageId) async => _update(
      messageId,
      (m) => m.copyWith(
          content: '', deletedAt: DateTime.now(), clearAttachment: true));

  @override
  Future<void> deleteForMe(String messageId) async {
    for (final messages in _messages.values) {
      messages.removeWhere((m) => m.id == messageId);
    }
    _deleted.add(messageId);
  }

  @override
  Future<void> setPin(
          {required String messageId, required bool pinned}) async =>
      _update(
          messageId,
          (m) => m.copyWith(
              pinnedAt: pinned ? DateTime.now() : null,
              clearPinnedAt: !pinned));

  @override
  Future<List<MessageEntity>> getPinnedMessages(String conversationId) async =>
      (_messages[conversationId] ?? []).where((m) => m.isPinned).toList();

  @override
  Future<List<MessageEntity>> searchInConversation(
          {required String conversationId, required String query}) async =>
      (_messages[conversationId] ?? [])
          .where((m) =>
              !m.isDeleted &&
              (m.content ?? '').toLowerCase().contains(query.toLowerCase()))
          .toList();

  @override
  Stream<MessageEntity> watchMessages(String conversationId) =>
      _incoming.stream.where((m) => m.conversationId == conversationId);

  @override
  Stream<String> watchMessageDeletes(String conversationId) => _deleted.stream;

  @override
  Stream<ReactionDelta> watchReactions() => const Stream<ReactionDelta>.empty();

  @override
  Future<int> sweepExpiredMessages() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
      'Это действие доступно в мобильном приложении, не в UI-превью');
}

class PreviewTypingChannel implements TypingChannel {
  @override
  Stream<Set<String>> get typingUsers => Stream<Set<String>>.value(<String>{});
  @override
  void connect() {}
  @override
  Future<void> ping() async {}
  @override
  Future<void> dispose() async {}
}
