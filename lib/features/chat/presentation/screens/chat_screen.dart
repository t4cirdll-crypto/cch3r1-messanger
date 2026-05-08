import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/services/notifications_listener.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../chat_list/domain/entities/conversation_entity.dart';
import '../../../chat_list/presentation/providers/chat_list_providers.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../providers/chat_providers.dart';
import '../services/attachment_picker.dart';
import '../../data/datasources/giphy_service.dart';
import '../widgets/attachment_menu_sheet.dart';
import '../widgets/gif_picker_sheet.dart';
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
  bool _showScrollToBottom = false;
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
      ref.read(activeConversationIdProvider.notifier).state =
          widget.conversationId;
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
    if (nextHasText) {
      // Внутри уже есть throttle (~2 sec).
      // ignore: discarded_futures
      ref.read(typingChannelProvider(widget.conversationId)).ping();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 120) {
      ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .loadMore();
    }
    // Список перевёрнут (`reverse: true`), поэтому «низ» — это `0`.
    final bool nextShow = _scrollController.position.pixels > 240;
    if (nextShow != _showScrollToBottom && mounted) {
      setState(() => _showScrollToBottom = nextShow);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    HapticFeedback.selectionClick();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    final StateController<String?> ctrl =
        ref.read(activeConversationIdProvider.notifier);
    if (ctrl.state == widget.conversationId) {
      ctrl.state = null;
    }
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String text = _controller.text;
    if (text.trim().isEmpty) return;
    final String? replyToId = _replyTo?.id;
    final MessageEntity? prevReply = _replyTo;
    // Чистим поле и reply-preview оптимистично, чтобы UI ощущался отзывчивым.
    // Если отправка свалится — текст и reply возвращаем обратно, чтобы юзер
    // не терял ввод (один из багов #3 в задаче).
    _controller.clear();
    setState(() => _replyTo = null);
    HapticFeedback.lightImpact();
    try {
      await ref
          .read(chatControllerProvider(widget.conversationId).notifier)
          .sendMessage(text, replyToId: replyToId);
    } catch (e) {
      if (!mounted) return;
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
      setState(() => _replyTo = prevReply);
      _toast('Не удалось отправить: $e');
    }
  }

  /// Прыжок к сообщению из баннера закреплённых: если оно загружено в текущей
  /// странице — скроллим к нему, иначе подсвечиваем по id (а пагинация
  /// дотащит его при следующем `loadMore`).
  void _jumpToMessage(MessageEntity target) {
    final ChatState? data = ref
        .read(chatControllerProvider(widget.conversationId))
        .valueOrNull;
    if (data == null) return;
    final List<MessageEntity> visible = data.messages
        .where((MessageEntity m) => !m.isExpired)
        .toList();
    final int positionFromTop =
        visible.indexWhere((MessageEntity m) => m.id == target.id);
    setState(() => _highlightId = target.id);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightId == target.id) {
        setState(() => _highlightId = null);
      }
    });
    if (positionFromTop < 0 || !_scrollController.hasClients) return;
    // Список перевёрнут: индекс в reverse-порядке.
    final int reverseIndex = visible.length - 1 - positionFromTop;
    // Пытаемся подскролить так, чтобы сообщение оказалось примерно по центру.
    const double approxItemHeight = 84;
    final double targetOffset = (reverseIndex * approxItemHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    HapticFeedback.selectionClick();
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
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
      case AttachmentMenuChoice.gif:
        if (!mounted) return;
        final GiphyGif? gif = await showGifPicker(context);
        if (gif == null || !mounted) return;
        await _uploadAndSend(OutgoingAttachment(
          kind: AttachmentKind.gif,
          mime: 'image/gif',
          extension: 'gif',
          remoteUrl: gif.fullUrl,
          name: gif.title.isEmpty ? 'GIF' : gif.title,
          width: gif.width,
          height: gif.height,
        ));
        return;
      default:
        return;
    }
    if (!mounted) return;
    if (result.permissionDenied) {
      _toast(result.errorMessage ?? 'Нет доступа');
      return;
    }
    if (result.errorMessage != null) {
      _toast(result.errorMessage!);
      return;
    }
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
      if (mounted) {
        final String dest = target.isDm
            ? '@${target.peer?.username ?? ''}'
            : target.effectiveTitle;
        _toast('Переслано в $dest');
      }
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
    final ConversationEntity? liveConv = _liveConversation(ref);

    return Scaffold(
      appBar: AppBar(
        title: _buildTitle(context, liveConv),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: liveConv?.muted ?? false
                ? AppStrings.muteOff
                : AppStrings.muteOn,
            icon: Icon(
              liveConv?.muted ?? false
                  ? Icons.notifications_off
                  : Icons.notifications_outlined,
              color: liveConv?.muted ?? false
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: () => _openMuteSheet(liveConv),
          ),
          IconButton(
            tooltip: liveConv?.hasSelfDestruct ?? false
                ? 'Исчезающие сообщения: '
                    '${_formatTtl((liveConv?.selfDestructSeconds) ?? 0)}'
                : 'Исчезающие сообщения',
            icon: Icon(
              liveConv?.hasSelfDestruct ?? false
                  ? Icons.timer
                  : Icons.timer_outlined,
              color: liveConv?.hasSelfDestruct ?? false
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: () => _openSelfDestructSheet(liveConv),
          ),
          IconButton(
            tooltip: AppStrings.searchInChat,
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _PinnedBanner(
            conversationId: widget.conversationId,
            onJumpToMessage: _jumpToMessage,
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                state.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (Object err, StackTrace st) =>
                      Center(child: Text('$err')),
                  data: (ChatState data) {
                    // Скрываем self-destruct сообщения, у которых истёк срок,
                    // даже если сервер ещё не успел их физически удалить.
                    final List<MessageEntity> visible = data.messages
                        .where((MessageEntity m) => !m.isExpired)
                        .toList();
                    if (visible.isEmpty) {
                      return _ChatEmptyState(
                        title: liveConv?.isGroup ?? false
                            ? 'Здесь пока тихо'
                            : 'Начните разговор',
                        subtitle:
                            'Сообщений ещё нет — отправьте первое или прикрепите файл.',
                      );
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount:
                          visible.length + (data.isLoadingMore ? 1 : 0),
                      itemBuilder: (BuildContext _, int index) {
                        if (data.isLoadingMore && index == visible.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child:
                                Center(child: CircularProgressIndicator()),
                          );
                        }
                        final int i = visible.length - 1 - index;
                        final MessageEntity m = visible[i];
                        final MessageEntity? prev =
                            i > 0 ? visible[i - 1] : null;
                        final bool showHeader = prev == null ||
                            !_sameDay(prev.createdAt, m.createdAt);
                        final bool isMine = m.isMine(uid);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (showHeader)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: Text(
                                    DateFormatter.messageDayHeader(
                                      m.createdAt,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              ),
                            MessageBubble(
                              message: m,
                              isMine: isMine,
                              showRead: isMine,
                              currentUserId: uid,
                              highlight: _highlightId == m.id,
                              onLongPress: () =>
                                  _openMessageActions(m, isMine),
                              onSwipeReply: m.isDeleted
                                  ? null
                                  : () => setState(() => _replyTo = m),
                              onReactionTap: (String emoji) {
                                HapticFeedback.selectionClick();
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
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    offset: _showScrollToBottom
                        ? Offset.zero
                        : const Offset(0, 1.4),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _showScrollToBottom ? 1 : 0,
                      child: _ScrollToBottomFab(
                        onTap: _scrollToBottom,
                      ),
                    ),
                  ),
                ),
              ],
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

  bool _sameDay(DateTime a, DateTime b) {
    final DateTime localA = a.toLocal();
    final DateTime localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  /// Возвращает свежие данные о диалоге из chatListController, если есть;
  /// иначе fallback на переданный в виджет `conversation`.
  ConversationEntity? _liveConversation(WidgetRef ref) {
    final AsyncValue<List<ConversationEntity>> all =
        ref.watch(chatListControllerProvider);
    final List<ConversationEntity>? list = all.valueOrNull;
    if (list != null) {
      for (final ConversationEntity c in list) {
        if (c.id == widget.conversationId) return c;
      }
    }
    return widget.conversation;
  }

  static String _formatTtl(int seconds) {
    if (seconds <= 0) return 'выкл';
    if (seconds < 60) return '$seconds сек';
    if (seconds < 3600) return '${seconds ~/ 60} мин';
    if (seconds < 86400) return '${seconds ~/ 3600} ч';
    return '${seconds ~/ 86400} д';
  }

  Future<void> _openMuteSheet(ConversationEntity? conv) async {
    final bool muted = conv?.muted ?? false;
    final List<({String label, Duration? duration})> options =
        <({String label, Duration? duration})>[
      if (muted) (label: AppStrings.muteOff, duration: const Duration()),
      (label: AppStrings.muteFor1Hour, duration: const Duration(hours: 1)),
      (label: AppStrings.muteFor8Hours, duration: const Duration(hours: 8)),
      (label: AppStrings.muteFor1Day, duration: const Duration(days: 1)),
      (label: AppStrings.muteFor1Week, duration: const Duration(days: 7)),
      (label: AppStrings.muteForever, duration: null),
    ];
    final ({String label, Duration? duration})? picked =
        await showModalBottomSheet<({String label, Duration? duration})>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                AppStrings.muteTitle,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            for (final ({String label, Duration? duration}) o in options)
              ListTile(
                leading: Icon(
                  o.duration?.inSeconds == 0
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                ),
                title: Text(o.label),
                onTap: () => Navigator.of(ctx).pop(o),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final DateTime? until;
    if (picked.duration == null) {
      // Forever — выбираем дату очень далеко в будущее.
      until = DateTime.utc(9999, 12, 31);
    } else if (picked.duration!.inSeconds == 0) {
      // Снять mute.
      until = null;
    } else {
      until = DateTime.now().toUtc().add(picked.duration!);
    }
    try {
      await ref.read(chatListControllerProvider.notifier).setMute(
            conversationId: widget.conversationId,
            until: until,
          );
      if (mounted) {
        _toast(until == null ? AppStrings.muteCleared : AppStrings.muteSet);
      }
    } catch (e) {
      if (mounted) _toast('Не удалось: $e');
    }
  }

  Future<void> _openSelfDestructSheet(ConversationEntity? conv) async {
    final int current = conv?.selfDestructSeconds ?? 0;
    final List<({String label, int seconds})> options =
        <({String label, int seconds})>[
      (label: 'Выключить', seconds: 0),
      (label: '5 секунд', seconds: 5),
      (label: '30 секунд', seconds: 30),
      (label: '1 минута', seconds: 60),
      (label: '5 минут', seconds: 300),
      (label: '1 час', seconds: 3600),
      (label: '24 часа', seconds: 86400),
    ];
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Исчезающие сообщения',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Новые сообщения автоматически удалятся у всех участников '
                'через выбранное время.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            for (final ({String label, int seconds}) o in options)
              ListTile(
                leading: Icon(
                  o.seconds == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: o.seconds == current
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                title: Text(o.label),
                onTap: () => Navigator.of(ctx).pop(o.seconds),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    try {
      await ref
          .read(chatListControllerProvider.notifier)
          .setSelfDestruct(
            conversationId: widget.conversationId,
            seconds: picked,
          );
      if (mounted) {
        _toast(picked == 0
            ? 'Исчезающие сообщения выключены'
            : 'Сообщения будут исчезать через ${_formatTtl(picked)}');
      }
    } catch (e) {
      if (mounted) _toast('Не удалось: $e');
    }
  }

  Widget _buildTitle(BuildContext context, ConversationEntity? convArg) {
    final ConversationEntity? conv = convArg ?? widget.conversation;
    if (conv == null) {
      return const Text('Чат');
    }

    final AsyncValue<Set<String>> typingAsync =
        ref.watch(typingUsersProvider(widget.conversationId));
    final Set<String> typing = typingAsync.valueOrNull ?? const <String>{};

    if (conv.isSaved) {
      return Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: const Icon(Icons.bookmark, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Saved Messages',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    if (conv.isGroup) {
      final String title = conv.effectiveTitle;
      final int count = conv.members.length;
      return InkWell(
        onTap: () => context.push('/group/${conv.id}/info'),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor:
                  Theme.of(context).colorScheme.onSecondaryContainer,
              child: Text(
                title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    typing.isNotEmpty
                        ? (typing.length == 1
                            ? 'печатает…'
                            : '${typing.length} печатают…')
                        : '$count участник(ов)',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: typing.isNotEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: typing.isNotEmpty
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final ProfileEntity? peer = conv.peer;
    if (peer == null) {
      return Text(conv.effectiveTitle);
    }
    return Row(
      children: <Widget>[
        UserAvatar(
          radius: 18,
          initial: peer.effectiveName.isNotEmpty
              ? peer.effectiveName.substring(0, 1).toUpperCase()
              : '?',
          avatarUrl: peer.avatarUrl,
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
                typing.contains(peer.id)
                    ? 'печатает…'
                    : peer.isOnline
                        ? AppStrings.online
                        : peer.lastSeen == null
                            ? ''
                            : AppStrings.lastSeen(
                                DateFormatter.lastSeenAgo(peer.lastSeen!),
                              ),
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: typing.contains(peer.id)
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color: typing.contains(peer.id)
                      ? Theme.of(context).colorScheme.primary
                      : peer.isOnline
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

/// Баннер закреплённых сообщений: показывает все закреплённые сообщения
/// с переключением по тапу (Telegram-style). Источник — отдельный
/// `pinnedMessagesProvider`, чтобы баннер не зависел от пагинации `messages`
/// и видел даже старые pin-нутые сообщения, которые ещё не подгружены.
class _PinnedBanner extends ConsumerStatefulWidget {
  const _PinnedBanner({
    required this.conversationId,
    required this.onJumpToMessage,
  });
  final String conversationId;
  final void Function(MessageEntity message) onJumpToMessage;

  @override
  ConsumerState<_PinnedBanner> createState() => _PinnedBannerState();
}

class _PinnedBannerState extends ConsumerState<_PinnedBanner> {
  /// Сколько раз пользователь тапнул по баннеру. Реальный индекс
  /// высчитывается по модулю длины списка — так сохраняется относительный
  /// порядок просмотра, даже если пины добавляются/удаляются на лету.
  int _tapCount = 0;

  @override
  Widget build(BuildContext context) {
    // Источник пинов — канонический список из repository, отсортированный
    // по `pinnedAt ASC`. Падать back на `state.messages` нельзя: пин может
    // быть вне первой страницы.
    final AsyncValue<List<MessageEntity>> pinnedAsync =
        ref.watch(pinnedMessagesProvider(widget.conversationId));
    final List<MessageEntity> raw =
        pinnedAsync.valueOrNull ?? const <MessageEntity>[];
    final List<MessageEntity> pinned = raw
        .where((MessageEntity m) => !m.isDeleted)
        .toList(growable: false);
    if (pinned.isEmpty) return const SizedBox.shrink();

    // Самый свежий pin показываем первым; дальше — по убыванию `pinnedAt`.
    final List<MessageEntity> ordered = List<MessageEntity>.of(pinned)
      ..sort((MessageEntity a, MessageEntity b) =>
          (b.pinnedAt ?? b.createdAt).compareTo(a.pinnedAt ?? a.createdAt));
    final int idx = ordered.isEmpty ? 0 : (_tapCount % ordered.length);
    final MessageEntity current = ordered[idx];
    final int total = ordered.length;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainerHigh,
      child: InkWell(
        onTap: () {
          if (total > 1) {
            setState(() => _tapCount = _tapCount + 1);
          }
          // Прыжок к сообщению вне зависимости от количества: даже один pin
          // должен открываться по тапу.
          widget.onJumpToMessage(current);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: <Widget>[
              // Если pin-ов несколько, рисуем вертикальную «лестницу» —
              // подсвечиваем сегмент, соответствующий текущему индексу.
              if (total > 1)
                _PinnedPositionIndicator(
                  total: total,
                  index: idx,
                  color: cs.primary,
                )
              else
                Icon(Icons.push_pin, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            total > 1
                                ? '${AppStrings.messagePinned} #${idx + 1}'
                                : AppStrings.messagePinned,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      previewMessageText(current),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (total > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${idx + 1}/$total',
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

/// Вертикальные сегменты-полоски слева от текста баннера; активный сегмент
/// окрашен в primary, остальные — приглушённо. Помогает видеть, на каком
/// именно из N pin-ов сейчас стоим.
class _PinnedPositionIndicator extends StatelessWidget {
  const _PinnedPositionIndicator({
    required this.total,
    required this.index,
    required this.color,
  });

  final int total;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Не больше 4 сегментов рисуем — иначе индикатор становится нечитаемым
    // на маленьких экранах.
    final int segments = total > 4 ? 4 : total;
    final int active = total <= 4
        ? index
        : ((index * segments) ~/ total).clamp(0, segments - 1);
    return SizedBox(
      width: 3,
      height: 36,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < segments; i++) ...<Widget>[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: i == active ? color : color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
            if (i != segments - 1) const SizedBox(height: 2),
          ],
        ],
      ),
    );
  }
}

class _ScrollToBottomFab extends StatelessWidget {
  const _ScrollToBottomFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: cs.shadow.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: cs.onSurface,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    cs.primaryContainer,
                    cs.tertiaryContainer,
                  ],
                ),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 44,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
