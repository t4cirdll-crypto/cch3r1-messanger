import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск по username / display name',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (String v) => setState(() => _query = v.trim().toLowerCase()),
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
                            (u.displayName ?? '').toLowerCase().contains(_query))
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
      leading: CircleAvatar(
        child: Text((user.displayName ?? user.username)
            .substring(0, 1)
            .toUpperCase()),
      ),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text('@${user.username}',
                style: TextStyle(
                  decoration: user.isBanned ? TextDecoration.lineThrough : null,
                )),
          ),
          if (user.isOnline)
            const Icon(Icons.circle, color: Colors.green, size: 10),
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
        case 'ban':
          final String? reason = await _askText(
              context, 'Причина бана (необязательно)', initial: '');
          await repo.setBanned(
              userId: user.id, banned: true, reason: reason);
          break;
        case 'unban':
          await repo.setBanned(userId: user.id, banned: false);
          break;
        case 'reset_password':
          final String? pwd = await _askText(
              context, 'Новый пароль (мин. 6 символов)', initial: '');
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
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.red),
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
      title: Text(label),
      content: TextField(controller: c, autofocus: true),
      actions: <Widget>[
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('OK')),
      ],
    ),
  );
}
