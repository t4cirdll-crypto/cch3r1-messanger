import '../../domain/entities/conversation_entity.dart';

enum ConversationFilter { all, unread, groups }

List<ConversationEntity> filterConversations(
  List<ConversationEntity> conversations, {
  required String query,
  required ConversationFilter filter,
}) {
  final String normalized =
      query.trim().toLowerCase().replaceFirst(RegExp(r'^@'), '');
  return conversations.where((ConversationEntity conversation) {
    if (filter == ConversationFilter.unread && conversation.unreadCount <= 0) {
      return false;
    }
    if (filter == ConversationFilter.groups && !conversation.isGroup) {
      return false;
    }
    return normalized.isEmpty ||
        conversation.effectiveTitle.toLowerCase().contains(normalized) ||
        (conversation.peer?.username.toLowerCase().contains(normalized) ??
            false);
  }).toList(growable: false);
}
