import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../providers/chat_providers.dart';
import '../widgets/reply_preview.dart';

class InChatSearchScreen extends ConsumerStatefulWidget {
  const InChatSearchScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<InChatSearchScreen> createState() => _InChatSearchScreenState();
}

class _InChatSearchScreenState extends ConsumerState<InChatSearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  List<MessageEntity> _results = const <MessageEntity>[];
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    final String trimmed = q.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const <MessageEntity>[];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(trimmed));
  }

  Future<void> _run(String q) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ChatRepository repo = await ref.read(chatRepositoryProvider.future);
      final List<MessageEntity> list = await repo.searchInConversation(
        conversationId: widget.conversationId,
        query: q,
      );
      if (!mounted) return;
      setState(() {
        _results = list;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: AppStrings.searchInChatHint,
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: <Widget>[
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _ctrl.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('$_error'))
              : _results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _ctrl.text.trim().isEmpty
                              ? AppStrings.searchInChatHint
                              : AppStrings.searchNoResults,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (BuildContext _, int i) {
                        final MessageEntity m = _results[i];
                        return ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text(
                            previewMessageText(m),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            DateFormatter.conversationTimestamp(m.createdAt),
                          ),
                          onTap: () => context.pop(m),
                        );
                      },
                    ),
    );
  }
}
