import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../chat_list/domain/entities/conversation_entity.dart';
import '../../../chat_list/presentation/providers/chat_list_providers.dart';
import '../providers/search_providers.dart';

import '../../../../core/widgets/user_avatar.dart';
import '../../../profile/presentation/widgets/user_profile_sheet.dart';

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
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: AppStrings.searchHint,
                prefixIcon: Icon(Icons.search),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                ),
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
                      padding: EdgeInsets.all(AppSpacing.xxxl),
                      child: Text(AppStrings.searchEmpty),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: AppSpacing.xxl + AppSpacing.xxl,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                  itemBuilder: (BuildContext _, int i) {
                    final ProfileEntity p = users[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.xs,
                      ),
                      onTap: () => UserProfileSheet.show(context, p.id),
                      leading: UserAvatar(
                        radius: 24,
                        initial: p.effectiveName.isNotEmpty
                            ? p.effectiveName.substring(0, 1).toUpperCase()
                            : '?',
                        avatarUrl: p.avatarUrl,
                      ),
                      title: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              p.effectiveName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (p.rank != null && p.rank!.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Builder(
                              builder: (BuildContext context) {
                                final bool isBot =
                                    p.rank!.toUpperCase() == 'BOT' ||
                                        p.rank!.toUpperCase() == 'БОТ';
                                final ColorScheme scheme =
                                    Theme.of(context).colorScheme;
                                final Color accent = isBot
                                    ? Colors.purple
                                    : scheme.primary;
                                return TweenAnimationBuilder<double>(
                                  duration: AppDurations.fast,
                                  curve: AppCurves.spring,
                                  tween: Tween<double>(begin: 0.85, end: 1),
                                  builder: (
                                    BuildContext context,
                                    double scale,
                                    Widget? child,
                                  ) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: AppSpacing.xxs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isBot
                                          ? Colors.purple
                                              .withValues(alpha: 0.15)
                                          : scheme.primaryContainer,
                                      borderRadius: AppRadius.xsAll,
                                      border: Border.all(
                                        color:
                                            accent.withValues(alpha: 0.4),
                                        width: 1,
                                      ),
                                      boxShadow:
                                          AppShadows.glow(accent, opacity: 0.18),
                                    ),
                                    child: Text(
                                      p.rank!.toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
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
