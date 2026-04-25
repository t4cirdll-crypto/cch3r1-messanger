import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
import '../widgets/message_bubble.dart';
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
    _controller.clear();
    await ref
        .read(chatControllerProvider(widget.conversationId).notifier)
        .sendMessage(text);
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
    setState(() => _uploading = true);
    try {
      await ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .sendAttachment(attachment, caption: caption);
      _controller.clear();
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
      ),
      body: Column(
        children: <Widget>[
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
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_uploading)
            const LinearProgressIndicator(minHeight: 2),
          VoiceRecorderOverlay(state: _voiceState),
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
