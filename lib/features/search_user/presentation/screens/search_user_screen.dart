import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../chat_list/domain/entities/conversation_entity.dart';
import '../../../chat_list/presentation/providers/chat_list_providers.dart';
import '../providers/search_providers.dart';

class SearchUserScreen extends ConsumerStatefulWidget {
  const SearchUserScreen({super.key});

  @override
  ConsumerState<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends ConsumerState<SearchUserScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  Future<void> _startConversation(ProfileEntity peer) async {
    try {
      final useCase =
          await ref.read(createOrGetConversationUseCaseProvider.future);
      final ConversationEntity conv = await useCase.call(peer.id);
      if (!mounted) return;
      context.pushReplacement('/chat/${conv.id}', extra: conv);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.somethingWentWrong}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ProfileEntity>> results =
        ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.searchTitle)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: AppStrings.searchHint,
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object err, StackTrace _) => Center(child: Text('$err')),
              data: (List<ProfileEntity> users) {
                if (users.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(AppStrings.searchEmpty),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext _, int i) {
                    final ProfileEntity p = users[i];
                    return ListTile(
                      onTap: () => _startConversation(p),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        backgroundImage: p.avatarUrl != null
                            ? CachedNetworkImageProvider(p.avatarUrl!)
                            : null,
                        child: p.avatarUrl == null
                            ? Text(
                                p.effectiveName.substring(0, 1).toUpperCase(),
                              )
                            : null,
                      ),
                      title: Text(p.effectiveName),
                      subtitle: Text('@${p.username}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        tooltip: AppStrings.startChat,
                        onPressed: () => _startConversation(p),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
