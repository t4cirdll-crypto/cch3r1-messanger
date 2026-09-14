import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../services/connection_service.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/chat_list_providers.dart';
import '../utils/conversation_filter.dart';
import '../widgets/chat_list_skeleton.dart';
import '../widgets/conversation_tile.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final TextEditingController _search = TextEditingController();
  ConversationFilter _filter = ConversationFilter.all;
  bool _openingSaved = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openSaved() async {
    if (_openingSaved) return;
    setState(() => _openingSaved = true);
    try {
      final ConversationEntity saved =
          await ref.read(chatListControllerProvider.notifier).openSaved();
      if (!mounted) return;
      context.push('/chat/${saved.id}', extra: saved);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.somethingWentWrong)),
      );
    } finally {
      if (mounted) setState(() => _openingSaved = false);
    }
  }

  void _resetFilters() {
    setState(() {
      _search.clear();
      _filter = ConversationFilter.all;
    });
  }

  Future<void> _compose() async {
    final String? route = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_rounded),
                title: const Text(AppStrings.newChat),
                subtitle: const Text('Найти человека по нику'),
                onTap: () => Navigator.of(context).pop('/search'),
              ),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text(AppStrings.newGroup),
                subtitle: const Text('Собрать всех в одном разговоре'),
                onTap: () => Navigator.of(context).pop('/group/new'),
              ),
            ],
          ),
        ),
      ),
    );
    if (route != null && mounted) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<ConversationEntity>> state =
        ref.watch(chatListControllerProvider);
    final String? uid = ref.watch(currentUserIdProvider);
    final bool offline = ref.watch(connectivityProvider).valueOrNull == false;
    final List<ConversationEntity> conversations =
        state.valueOrNull ?? const <ConversationEntity>[];
    final int unread =
        conversations.where((ConversationEntity c) => c.unreadCount > 0).length;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: NestedScrollView(
              headerSliverBuilder: (_, __) => <Widget>[
                SliverToBoxAdapter(
                  child: Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xxl,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: cs.primary,
                                borderRadius: AppRadius.smAll,
                              ),
                              child: Icon(Icons.forum_rounded,
                                  color: cs.onPrimary, size: 22),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                'cch3r1',
                                style: theme.textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: AppStrings.savedMessages,
                              onPressed: _openingSaved ? null : _openSaved,
                              icon: _openingSaved
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.bookmark_border_rounded),
                            ),
                            IconButton(
                              tooltip: AppStrings.profileTitle,
                              onPressed: () => context.push('/profile'),
                              icon: const Icon(Icons.account_circle_outlined),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xxl,
                          AppSpacing.lg,
                          AppSpacing.xxl,
                          AppSpacing.xl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              AppStrings.inboxTitle,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              AppStrings.inboxSubtitle,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            TextField(
                              key: const ValueKey<String>('inbox-search'),
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                              textInputAction: TextInputAction.search,
                              autocorrect: false,
                              decoration: InputDecoration(
                                hintText: AppStrings.inboxSearchHint,
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: AppStrings.clearSearch,
                                        onPressed: () =>
                                            setState(_search.clear),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                fillColor: cs.surfaceContainerLowest,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.lg,
                                  vertical: AppSpacing.md,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: <Widget>[
                                  for (final ConversationFilter filter
                                      in ConversationFilter.values)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          right: AppSpacing.sm),
                                      child: ChoiceChip(
                                        key: ValueKey<ConversationFilter>(
                                            filter),
                                        showCheckmark: false,
                                        label: Text(switch (filter) {
                                          ConversationFilter.all =>
                                            AppStrings.allChats,
                                          ConversationFilter.unread => unread >
                                                  0
                                              ? '${AppStrings.unreadChats} · $unread'
                                              : AppStrings.unreadChats,
                                          ConversationFilter.groups =>
                                            AppStrings.groupChats,
                                        }),
                                        selected: _filter == filter,
                                        onSelected: (_) =>
                                            setState(() => _filter = filter),
                                        selectedColor: cs.primary,
                                        backgroundColor:
                                            cs.surfaceContainerLowest,
                                        side: BorderSide(
                                          color: _filter == filter
                                              ? Colors.transparent
                                              : cs.outlineVariant,
                                        ),
                                        labelStyle: TextStyle(
                                          color: _filter == filter
                                              ? cs.onPrimary
                                              : cs.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (offline)
                        const _StatusBanner(
                          icon: Icons.wifi_off_rounded,
                          text: AppStrings.inboxOfflineHint,
                        ),
                      if (state.hasError && state.hasValue)
                        _StatusBanner(
                          icon: Icons.sync_problem_rounded,
                          text: AppStrings.inboxRefreshError,
                          onRetry: () => ref
                              .read(chatListControllerProvider.notifier)
                              .refresh(),
                        ),
                      SizedBox(
                        height: 2,
                        child: state.isLoading && state.hasValue
                            ? const LinearProgressIndicator(minHeight: 2)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
              body: Material(
                color: cs.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xxl),
                  ),
                  side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.55)),
                ),
                clipBehavior: Clip.antiAlias,
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(chatListControllerProvider.notifier).refresh(),
                  child: state.when(
                    skipError: true,
                    data: (List<ConversationEntity> list) {
                      final List<ConversationEntity> visible =
                          filterConversations(list,
                              query: _search.text, filter: _filter);
                      if (visible.isEmpty) {
                        final bool filtered = _search.text.trim().isNotEmpty ||
                            _filter != ConversationFilter.all;
                        return _InboxPlaceholder(
                          icon: filtered
                              ? Icons.search_off_rounded
                              : Icons.mark_chat_unread_outlined,
                          title: filtered
                              ? AppStrings.inboxNoResults
                              : AppStrings.chatsEmpty,
                          subtitle: filtered
                              ? AppStrings.inboxNoResultsHint
                              : AppStrings.inboxEmptyHint,
                          action: filtered
                              ? AppStrings.resetFilters
                              : AppStrings.newChat,
                          onAction: filtered ? _resetFilters : _compose,
                        );
                      }
                      return ListView.separated(
                        key: const PageStorageKey<String>('inbox-list'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          bottom: 104,
                        ),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 84,
                          endIndent: AppSpacing.xxl,
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                        ),
                        itemBuilder: (BuildContext context, int i) {
                          final ConversationEntity c = visible[i];
                          return ConversationTile(
                            key: ValueKey<String>(c.id),
                            conversation: c,
                            currentUserId: uid,
                            onTap: () =>
                                context.push('/chat/${c.id}', extra: c),
                          );
                        },
                      );
                    },
                    loading: () => const ChatListSkeleton(),
                    error: (_, __) => _InboxPlaceholder(
                      icon: Icons.cloud_off_rounded,
                      title: AppStrings.inboxLoadError,
                      subtitle: 'Проверьте подключение и попробуйте ещё раз.',
                      action: AppStrings.retry,
                      onAction: () => ref
                          .read(chatListControllerProvider.notifier)
                          .refresh(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          right: ((MediaQuery.sizeOf(context).width - 760) / 2)
              .clamp(0.0, double.infinity),
        ),
        child: FloatingActionButton.extended(
          onPressed: _compose,
          icon: const Icon(Icons.edit_square),
          label: const Text(AppStrings.newChat),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
          if (onRetry != null)
            IconButton(
              tooltip: AppStrings.retry,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }
}

class _InboxPlaceholder extends StatelessWidget {
  const _InboxPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxxl,
              AppSpacing.xxl,
              AppSpacing.xxxl,
              104,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircleAvatar(
                  radius: 36,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(icon, color: cs.onPrimaryContainer, size: 32),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.md),
                TextButton(onPressed: onAction, child: Text(action)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
