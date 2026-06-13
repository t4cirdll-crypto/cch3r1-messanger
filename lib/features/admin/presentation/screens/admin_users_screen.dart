import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cch3r1_messanger/core/theme/app_tokens.dart';
import '../../data/admin_repository.dart';
import '../../domain/entities/admin_entities.dart';
import '../providers/admin_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AdminUser>> users = ref.watch(adminUsersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminUsersProvider),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск по username / display name',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdAll,
                ),
              ),
              onChanged: (String v) =>
                  setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace _) => Center(child: Text('$e')),
              data: (List<AdminUser> list) {
                final List<AdminUser> filtered = _query.isEmpty
                    ? list
                    : list
                        .where((AdminUser u) =>
                            u.username.toLowerCase().contains(_query) ||
                            (u.displayName ?? '')
                                .toLowerCase()
                                .contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('Никого не найдено'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(adminUsersProvider),
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext _, int i) =>
                        _UserTile(user: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        alignment: Alignment.center,
        child: Text(
          (user.displayName ?? user.username).substring(0, 1).toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text('@${user.username}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        decoration:
                            user.isBanned ? TextDecoration.lineThrough : null,
                      )),
                ),
                if (user.rank != null && user.rank!.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Builder(
                    builder: (BuildContext ctx) {
                      final String r = user.rank!.toUpperCase();
                      final ColorScheme cs = Theme.of(ctx).colorScheme;
                      final Color bg;
                      final Color border;
                      final Color text;
                      if (r == 'BOT' || r == 'БОТ') {
                        bg = Colors.purple.withValues(alpha: 0.15);
                        border = Colors.purple.withValues(alpha: 0.4);
                        text = Colors.purple;
                      } else if (r == 'ADMIN' || r == 'АДМИН') {
                        bg = Colors.red.withValues(alpha: 0.15);
                        border = Colors.red.withValues(alpha: 0.4);
                        text = Colors.red;
                      } else if (r == 'VIP') {
                        bg = Colors.amber.withValues(alpha: 0.15);
                        border = Colors.amber.withValues(alpha: 0.4);
                        text = Colors.amber.shade800;
                      } else {
                        bg = cs.primaryContainer;
                        border = cs.primary.withValues(alpha: 0.4);
                        text = cs.primary;
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: AppRadius.xsAll,
                          border: Border.all(color: border, width: 1),
                        ),
                        child: Text(
                          user.rank!.toUpperCase(),
                          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: text,
                              ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          if (user.isOnline)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: AppShadows.glow(Colors.green, opacity: 0.5),
              ),
            ),
        ],
      ),
      subtitle: Text(
        <String>[
          if (user.displayName != null && user.displayName!.isNotEmpty)
            user.displayName!,
          'msg: ${user.messageCount}',
          if (user.email != null) user.email!,
          if (user.isBanned) '🚫 ${user.bannedReason ?? "забанен"}',
        ].join(' • '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (String action) => _handleAction(context, ref, action),
        itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: user.isBanned ? 'unban' : 'ban',
            child: Text(user.isBanned ? 'Разбанить' : 'Забанить'),
          ),
          const PopupMenuItem<String>(
            value: 'set_rank',
            child: Text('Изменить ранг'),
          ),
          const PopupMenuItem<String>(
            value: 'reset_password',
            child: Text('Сбросить пароль'),
          ),
          const PopupMenuItem<String>(
            value: 'delete',
            child: Text('Удалить пользователя'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String action) async {
    final AdminRepository repo = ref.read(adminRepositoryProvider);
    try {
      switch (action) {
        case 'set_rank':
          final String? newRank = await _askText(context,
              'Укажите ранг (например, БОТ, VIP, ADMIN или пусто для сброса)',
              initial: user.rank ?? '');
          if (newRank == null) return;
          await repo.setRank(userId: user.id, rank: newRank);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ранг пользователя обновлен')),
            );
          }
          break;
        case 'ban':
          final String? reason = await _askText(
              context, 'Причина бана (необязательно)',
              initial: '');
          await repo.setBanned(userId: user.id, banned: true, reason: reason);
          break;
        case 'unban':
          await repo.setBanned(userId: user.id, banned: false);
          break;
        case 'reset_password':
          final String? pwd = await _askText(
              context, 'Новый пароль (мин. 6 символов)',
              initial: '');
          if (pwd == null || pwd.length < 6) return;
          await repo.resetPassword(userId: user.id, newPassword: pwd);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Пароль обновлён')),
            );
          }
          return;
        case 'delete':
          final bool? ok = await showDialog<bool>(
            context: context,
            builder: (BuildContext ctx) => AlertDialog(
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.xlAll,
              ),
              title: const Text('Удалить пользователя?'),
              content: Text(
                'Будет удалён @${user.username} и все его сообщения. '
                'Действие необратимо.',
              ),
              actions: <Widget>[
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Отмена')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Удалить')),
              ],
            ),
          );
          if (ok != true) return;
          await repo.deleteUser(user.id);
          break;
      }
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminStatsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
}

Future<String?> _askText(BuildContext context, String label,
    {String initial = ''}) async {
  final TextEditingController c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.xlAll,
      ),
      title: Text(label),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('OK')),
      ],
    ),
  );
}
