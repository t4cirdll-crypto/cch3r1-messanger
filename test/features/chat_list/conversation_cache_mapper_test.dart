import 'package:flutter_test/flutter_test.dart';

import 'package:cch3r1_messanger/features/auth/domain/entities/profile_entity.dart';
import 'package:cch3r1_messanger/features/chat/domain/entities/message_entity.dart';
import 'package:cch3r1_messanger/features/chat_list/data/datasources/chat_list_local_datasource.dart';
import 'package:cch3r1_messanger/features/chat_list/domain/entities/conversation_entity.dart';

void main() {
  test('preserves last-message visibility and attachment metadata', () {
    final DateTime createdAt = DateTime.utc(2026, 9, 14, 4, 5, 6, 789);
    final DateTime deletedAt = DateTime.utc(2026, 9, 14, 4, 6);
    final DateTime expiresAt = DateTime.utc(2020, 1, 2);
    final ConversationEntity conversation = ConversationEntity(
      id: 'conversation-1',
      kind: ConversationKind.dm,
      updatedAt: createdAt,
      members: const <ConversationMember>[],
      peer: const ProfileEntity(id: 'peer-1', username: 'peer'),
      lastMessage: MessageEntity(
        id: 'message-1',
        conversationId: 'conversation-1',
        senderId: 'peer-1',
        content: 'private cached text',
        createdAt: createdAt,
        deletedAt: deletedAt,
        expiresAt: expiresAt,
        attachmentKind: AttachmentKind.file,
        attachmentName: 'receipt.pdf',
      ),
    );

    final Map<String, Object?> row = ConversationCacheMapper.toRow(
      'account-1',
      conversation,
    );
    final ConversationEntity restored = ConversationCacheMapper.fromRow(row);
    final MessageEntity restoredMessage = restored.lastMessage!;

    expect(row['account_id'], 'account-1');
    expect(row['last_message_deleted_at'], deletedAt.millisecondsSinceEpoch);
    expect(row['last_message_expires_at'], expiresAt.millisecondsSinceEpoch);
    expect(row['last_message_attachment_kind'], AttachmentKind.file.value);
    expect(row['last_message_attachment_name'], 'receipt.pdf');
    expect(restoredMessage.deletedAt, isNotNull);
    expect(restoredMessage.deletedAt!.isAtSameMomentAs(deletedAt), isTrue);
    expect(restoredMessage.expiresAt, isNotNull);
    expect(restoredMessage.expiresAt!.isAtSameMomentAs(expiresAt), isTrue);
    expect(restoredMessage.attachmentKind, AttachmentKind.file);
    expect(restoredMessage.attachmentName, 'receipt.pdf');
    expect(restoredMessage.isDeleted, isTrue);
    expect(restoredMessage.isExpired, isTrue);
  });
}
