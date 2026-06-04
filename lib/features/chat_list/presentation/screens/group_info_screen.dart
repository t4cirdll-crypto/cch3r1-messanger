import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../profile/presentation/widgets/user_profile_sheet.dart';
import '../../../search_user/presentation/providers/search_providers.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/repositories/chat_list_repository.dart';
import '../providers/chat_list_providers.dart';
import '../../../../core/widgets/glass_widgets.dart';

/// Экран «Информация о группе» — показывает участников группы,
/// позволяет переименовать, добавить/удалить участников, выйти.
class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  bool _busy = false;

  ConversationEntity? _findConv(List<ConversationEntity> list) {
    for (final ConversationEntity c in list) {
      if (c.id == widget.conversationId) return c;
    }
    return null;
  }

  Future<void> _renameGroup(ConversationEntity conv) async {
    final TextEditingController ctrl =
        TextEditingController(text: conv.title ?? '');
    final String? next = await showDialog<String?>(
      context: context,
      builder: (BuildContext _) => AlertDialog(
        title: const Text('Название группы'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Новое название'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
    if (next == null || next.isEmpty) return;
    await _withBusy(() async {
      final ChatListRepository repo =
          await ref.read(chatListRepositoryProvider.future);
      await repo.setGroupTitle(
        conversationId: widget.conversationId,
        title: next,
      );
      await ref.read(chatListControllerProvider.notifier).refresh();
    });
  }

  Future<void> _removeMember(ProfileEntity p) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => AlertDialog(
        title: const Text('Удалить участника?'),
        content: Text('Удалить ${p.effectiveName} из группы?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _withBusy(() async {
      final ChatListRepository repo =
          await ref.read(chatListRepositoryProvider.future);
      await repo.removeMember(
        conversationId: widget.conversationId,
        userId: p.id,
      );
      await ref.read(chatListControllerProvider.notifier).refresh();
    });
  }

  Future<void> _leave() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext _) => AlertDialog(
        title: const Text('Выйти из группы?'),
        content: const Text(
          'Вы перестанете получать сообщения из этой группы.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _withBusy(() async {
      final ChatListRepository repo =
          await ref.read(chatListRepositoryProvider.future);
      await repo.leaveConversation(widget.conversationId);
      await ref.read(chatListControllerProvider.notifier).refresh();
    });
    if (mounted) context.go('/');
  }

  Future<void> _addMembers(ConversationEntity conv) async {
    final Set<String> already =
        conv.members.map((ConversationMember m) => m.profile.id).toSet();
    final List<ProfileEntity>? picked = await showModalBottomSheet<List<ProfileEntity>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext _) => _AddMembersSheet(excluded: already),
    );
    if (picked == null || picked.isEmpty) return;
    await _withBusy(() async {
      final ChatListRepository repo =
          await ref.read(chatListRepositoryProvider.future);
      for (final ProfileEntity p in picked) {
        await repo.addMember(
          conversationId: widget.conversationId,
          userId: p.id,
        );
      }
      await ref.read(chatListControllerProvider.notifier).refresh();
    });
  }

  Future<void> _withBusy(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.somethingWentWrong}: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? uid = ref.watch(currentUserIdProvider);
    final AsyncValue<List<ConversationEntity>> state =
        ref.watch(chatListControllerProvider);

    return Scaffold(
      appBar: const GlassmorphicAppBar(
        title: Text('Информация'),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => Center(child: Text('$err')),
        data: (List<ConversationEntity> list) {
          final ConversationEntity? conv = _findConv(list);
          if (conv == null) {
            return const Center(child: Text('Группа не найдена'));
          }
          if (!conv.isGroup) {
            return const Center(child: Text('Это не группа'));
          }
          final ConversationMember? me = _findMe(conv, uid);
          final bool canEdit = me != null &&
              (me.role == MemberRole.owner || me.role == MemberRole.admin);

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            children: <Widget>[
              // Group Details Card
              GlassmorphicCard(
                child: Column(
                  children: <Widget>[
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.glow(
                            theme.colorScheme.primary,
                            opacity: 0.22,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor:
                              theme.colorScheme.secondaryContainer,
                          child: Text(
                            conv.effectiveTitle.isEmpty
                                ? '?'
                                : conv.effectiveTitle
                                    .substring(0, 1)
                                    .toUpperCase(),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        conv.effectiveTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          '${conv.members.length} участник(ов)',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      trailing: canEdit
                          ? IconButton(
                              tooltip: 'Переименовать',
                              icon: const Icon(Icons.edit),
                              onPressed:
                                  _busy ? null : () => _renameGroup(conv),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Members List Card
              GlassmorphicCard(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: <Widget>[
                    if (canEdit)
                      ListTile(
                        leading: const Icon(Icons.person_add),
                        title: const Text('Добавить участников'),
                        onTap: _busy ? null : () => _addMembers(conv),
                      ),
                    if (canEdit)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: AppSpacing.lg,
                        endIndent: AppSpacing.lg,
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                    ...conv.members.map((ConversationMember m) => _MemberTile(
                          member: m,
                          isMe: m.profile.id == uid,
                          canRemove: canEdit && m.profile.id != uid,
                          onRemove: () => _removeMember(m.profile),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Actions Card
              GlassmorphicCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(Icons.exit_to_app,
                      color: theme.colorScheme.error),
                  title: Text(
                    'Выйти из группы',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _busy ? null : _leave,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }

  static ConversationMember? _findMe(ConversationEntity c, String? uid) {
    if (uid == null) return null;
    for (final ConversationMember m in c.members) {
      if (m.profile.id == uid) return m;
    }
    return null;
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canRemove,
    required this.onRemove,
  });

  final ConversationMember member;
  final bool isMe;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ProfileEntity p = member.profile;
    return ListTile(
      onTap: () => UserProfileSheet.show(context, p.id),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: theme.colorScheme.primaryContainer,
        backgroundImage: p.avatarUrl != null
            ? CachedNetworkImageProvider(p.avatarUrl!)
            : null,
        child: p.avatarUrl == null
            ? Text(
                p.effectiveName.isEmpty
                    ? '?'
                    : p.effectiveName.substring(0, 1).toUpperCase(),
              )
            : null,
      ),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              isMe ? '${p.effectiveName} (вы)' : p.effectiveName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (member.role != MemberRole.member)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: member.role == MemberRole.owner
                      ? theme.colorScheme.primary
                      : theme.colorScheme.tertiary,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppRadius.pill),
                  ),
                ),
                child: Text(
                  member.role == MemberRole.owner ? 'OWNER' : 'ADMIN',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: member.role == MemberRole.owner
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
        ],
      ),
      subtitle: Text('@${p.username}'),
      trailing: canRemove
          ? IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.person_remove),
              onPressed: onRemove,
            )
          : null,
    );
  }
}

/// Bottom-sheet с поиском и мультивыбором новых участников группы.
class _AddMembersSheet extends ConsumerStatefulWidget {
  const _AddMembersSheet({required this.excluded});

  final Set<String> excluded;

  @override
  ConsumerState<_AddMembersSheet> createState() => _AddMembersSheetState();
}

class _AddMembersSheetState extends ConsumerState<_AddMembersSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final Map<String, ProfileEntity> _selected = <String, ProfileEntity>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchQueryProvider.notifier).state = '';
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ProfileEntity>> results =
        ref.watch(searchResultsProvider);
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Добавить участников',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context)
                            .pop(_selected.values.toList()),
                    child: Text('Добавить (${_selected.length})'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (String v) =>
                    ref.read(searchQueryProvider.notifier).state = v,
                decoration: const InputDecoration(
                  hintText: AppStrings.searchHint,
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: results.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (Object err, StackTrace _) =>
                    Center(child: Text('$err')),
                data: (List<ProfileEntity> users) {
                  final List<ProfileEntity> filtered = users
                      .where((ProfileEntity p) => !widget.excluded.contains(p.id))
                      .toList();
                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Text('Никого не найдено'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (BuildContext _, int i) {
                      final ProfileEntity p = filtered[i];
                      final bool selected = _selected.containsKey(p.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (_) {
                          setState(() {
                            if (selected) {
                              _selected.remove(p.id);
                            } else {
                              _selected[p.id] = p;
                            }
                          });
                        },
                        title: Text(p.effectiveName),
                        subtitle: Text('@${p.username}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
