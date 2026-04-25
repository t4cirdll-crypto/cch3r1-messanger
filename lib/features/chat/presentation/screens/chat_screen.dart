import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/utils/date_format.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../chat_list/domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../providers/chat_providers.dart';
import '../services/attachment_picker.dart';
import '../widgets/attachment_menu_sheet.dart';
import '../widgets/message_actions_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reply_preview.dart';
import '../widgets/voice_recorder_button.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  final String conversationId;
  final ConversationEntity? conversation;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;
  bool _uploading = false;
  MessageEntity? _replyTo;
  String? _highlightId;
  VoiceRecorderState _voiceState = const VoiceRecorderState(
    isRecording: false,
    isCancelling: false,
    elapsed: Duration.zero,
  );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .markAsRead();
    });
  }

  void _onTextChanged() {
    final bool nextHasText = _controller.text.trim().isNotEmpty;
    if (nextHasText != _hasText) {
      setState(() => _hasText = nextHasText);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _controller.text;
    if (text.trim().isEmpty) return;
    final String? replyToId = _replyTo?.id;
    _controller.clear();
    setState(() => _replyTo = null);
    await ref
        .read(chatControllerProvider(widget.conversationId).notifier)
        .sendMessage(text, replyToId: replyToId);
  }

  Future<void> _openAttachmentMenu() async {
    final AttachmentMenuChoice? choice =
        await AttachmentMenuSheet.show(context);
    if (choice == null) return;
    AttachmentPickerResult result;
    switch (choice) {
      case AttachmentMenuChoice.camera:
        result = await AttachmentPicker.pickImage(fromCamera: true);
      case AttachmentMenuChoice.gallery:
        result = await AttachmentPicker.pickImage();
      case AttachmentMenuChoice.video:
        result = await AttachmentPicker.pickVideo();
      case AttachmentMenuChoice.file:
        result = await AttachmentPicker.pickFile();
      default:
        return;
    }
    if (!mounted) return;
    if (result.tooLarge) {
      _toast('Файл больше 25 МБ — выберите меньший');
      return;
    }
    if (result.attachment == null) return;
    await _uploadAndSend(result.attachment!);
  }

  Future<void> _uploadAndSend(OutgoingAttachment attachment) async {
    final String? caption = _controller.text.trim().isEmpty
        ? null
        : _controller.text.trim();
    final String? replyToId = _replyTo?.id;
    setState(() => _uploading = true);
    try {
      await ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .sendAttachment(attachment, caption: caption, replyToId: replyToId);
      _controller.clear();
      if (mounted) setState(() => _replyTo = null);
    } catch (e) {
      if (mounted) _toast('Не удалось отправить: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openMessageActions(MessageEntity m, bool isMine) async {
    final ChatController controller =
        ref.read(chatControllerProvider(widget.conversationId).notifier);
    final MessageAction? action = await MessageActionsSheet.show(
      context,
      message: m,
      isMine: isMine,
      onPickEmoji: (String emoji) => controller.toggleReaction(m.id, emoji),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case MessageAction.reply:
        setState(() => _replyTo = m);
      case MessageAction.edit:
        await _editMessage(m);
      case MessageAction.copy:
        await Clipboard.setData(
          ClipboardData(text: (m.content ?? '').trim()),
        );
        if (mounted) _toast('Скопировано');
      case MessageAction.forward:
        await _forwardMessage(m);
      case MessageAction.pin:
      case MessageAction.unpin:
        await controller.togglePin(m.id);
      case MessageAction.deleteForMe:
        await controller.deleteMessage(m.id, forAll: false);
      case MessageAction.deleteForAll:
        final bool? ok = await showDialog<bool>(
          context: context,
          builder: (BuildContext _) => AlertDialog(
            title: const Text(AppStrings.actionDeleteForAll),
            content: const Text('Сообщение будет удалено у всех участников.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(AppStrings.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(AppStrings.actionDelete),
              ),
            ],
          ),
        );
        if (ok == true) await controller.deleteMessage(m.id, forAll: true);
    }
  }

  Future<void> _editMessage(MessageEntity m) async {
    final TextEditingController ctrl =
        TextEditingController(text: m.content ?? '');
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext _) => AlertDialog(
        title: const Text(AppStrings.editTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          decoration: const InputDecoration(hintText: AppStrings.editHint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
    if (next == null || next.isEmpty) return;
    if (next == (m.content ?? '').trim()) return;
    try {
      await ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .editMessage(m.id, next);
    } catch (e) {
      if (mounted) _toast('$e');
    }
  }

  Future<void> _forwardMessage(MessageEntity m) async {
    final ConversationEntity? target =
        await context.push<ConversationEntity?>('/forward-picker');
    if (target == null || !mounted) return;
    try {
      final ChatRepository repo =
          await ref.read(chatRepositoryProvider.future);
      String? content = m.content;
      if (m.hasAttachment && (content == null || content.isEmpty)) {
        content = '[вложение: ${m.attachmentKind?.value ?? 'файл'}]';
      }
      await repo.sendMessage(
        conversationId: target.id,
        content: content,
        forwardedFromMessageId: m.id,
        forwardedFromSenderId: m.senderId,
      );
      if (mounted) _toast('Переслано в @${target.peer.username}');
    } catch (e) {
      if (mounted) _toast('Не удалось переслать: $e');
    }
  }

  Future<void> _openSearch() async {
    final MessageEntity? jump = await context
        .push<MessageEntity?>('/chat/${widget.conversationId}/search');
    if (jump == null || !mounted) return;
    setState(() => _highlightId = jump.id);
    // Подсветка снимается через 2 сек.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightId == jump.id) {
        setState(() => _highlightId = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ChatState> state =
        ref.watch(chatControllerProvider(widget.conversationId));
    final String? uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: AppStrings.searchInChat,
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _PinnedBanner(conversationId: widget.conversationId),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object err, StackTrace st) =>
                  Center(child: Text('$err')),
              data: (ChatState data) {
                if (data.messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Сообщений пока нет. Напишите первое!'),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount:
                      data.messages.length + (data.isLoadingMore ? 1 : 0),
                  itemBuilder: (BuildContext _, int index) {
                    if (data.isLoadingMore &&
                        index == data.messages.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final int i = data.messages.length - 1 - index;
                    final MessageEntity m = data.messages[i];
                    final MessageEntity? prev =
                        i > 0 ? data.messages[i - 1] : null;
                    final bool showHeader = prev == null ||
                        !_sameDay(prev.createdAt, m.createdAt);
                    final bool isMine = m.isMine(uid);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(
                                DateFormatter.conversationTimestamp(
                                  m.createdAt,
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        MessageBubble(
                          message: m,
                          isMine: isMine,
                          showRead: isMine,
                          currentUserId: uid,
                          highlight: _highlightId == m.id,
                          onLongPress: () => _openMessageActions(m, isMine),
                          onReactionTap: (String emoji) {
                            ref
                                .read(chatControllerProvider(
                                        widget.conversationId)
                                    .notifier)
                                .toggleReaction(m.id, emoji);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_uploading) const LinearProgressIndicator(minHeight: 2),
          VoiceRecorderOverlay(state: _voiceState),
          if (_replyTo != null)
            ReplyPreview(
              message: _replyTo!,
              onCancel: () => setState(() => _replyTo = null),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Прикрепить',
                    onPressed: _voiceState.isRecording || _uploading
                        ? null
                        : _openAttachmentMenu,
                    icon: const Icon(Icons.attach_file_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      enabled: !_voiceState.isRecording,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: AppStrings.messageHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_hasText)
                    IconButton.filled(
                      tooltip: AppStrings.messageSend,
                      onPressed: _uploading ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                    )
                  else
                    VoiceRecorderButton(
                      onStateChanged: (VoiceRecorderState s) {
                        if (mounted) setState(() => _voiceState = s);
                      },
                      onError: _toast,
                      onRecorded: _uploadAndSend,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildTitle(BuildContext context) {
    final ProfileEntity? peer = widget.conversation?.peer;
    if (peer == null) {
      return const Text('Чат');
    }
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          backgroundImage: peer.avatarUrl != null
              ? CachedNetworkImageProvider(peer.avatarUrl!)
              : null,
          child: peer.avatarUrl == null
              ? Text(peer.effectiveName.substring(0, 1).toUpperCase())
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                peer.effectiveName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                peer.isOnline
                    ? AppStrings.online
                    : peer.lastSeen == null
                        ? ''
                        : AppStrings.lastSeen(
                            DateFormatter.lastSeenAgo(peer.lastSeen!),
                          ),
                style: TextStyle(
                  fontSize: 12,
                  color: peer.isOnline
                      ? Colors.green
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinnedBanner extends ConsumerWidget {
  const _PinnedBanner({required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ChatState> state =
        ref.watch(chatControllerProvider(conversationId));
    final List<MessageEntity> pinned = state.valueOrNull?.messages
            .where((MessageEntity m) => m.isPinned && !m.isDeleted)
            .toList() ??
        const <MessageEntity>[];
    if (pinned.isEmpty) return const SizedBox.shrink();
    pinned.sort((MessageEntity a, MessageEntity b) =>
        (b.pinnedAt ?? b.createdAt).compareTo(a.pinnedAt ?? a.createdAt));
    final MessageEntity top = pinned.first;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: <Widget>[
              Icon(Icons.push_pin, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppStrings.messagePinned,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      previewMessageText(top),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (pinned.length > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${pinned.length}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
