import 'package:cch3r1_messanger/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/admin_entities.dart';
import '../providers/admin_providers.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdminStats> stats = ref.watch(adminStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Админка'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminStatsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminStatsProvider),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            stats.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object err, StackTrace _) => Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Ошибка: $err',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
              data: (AdminStats s) => _StatsGrid(stats: s),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SectionTile(
              icon: Icons.people_outline,
              title: 'Пользователи',
              subtitle:
                  'Список, бан/разбан, удаление, сброс пароля',
              onTap: () => context.push('/admin/users'),
            ),
            _SectionTile(
              icon: Icons.forum_outlined,
              title: 'Диалоги и группы',
              subtitle: 'Все чаты + просмотр сообщений (read-only)',
              onTap: () => context.push('/admin/conversations'),
            ),
            _SectionTile(
              icon: Icons.campaign_outlined,
              title: 'Широковещание',
              subtitle: 'Отправить сообщение всем юзерам',
              onTap: () => context.push('/admin/broadcast'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<_Stat> items = <_Stat>[
      _Stat('Юзеры', stats.usersTotal, Icons.people_outline),
      _Stat('Онлайн', stats.usersOnline, Icons.circle, color: Colors.green),
      _Stat('Забанено', stats.usersBanned, Icons.block, color: Colors.red),
      _Stat('Диалоги', stats.conversationsTotal, Icons.chat_bubble_outline),
      _Stat('Группы', stats.groupsTotal, Icons.group_outlined),
      _Stat('Сообщений', stats.messagesTotal, Icons.message_outlined),
      _Stat('За 24ч', stats.messagesToday, Icons.today_outlined),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: items
          .map((_Stat e) => SizedBox(
                width: (MediaQuery.of(context).size.width -
                        AppSpacing.lg * 2 -
                        AppSpacing.sm) /
                    2,
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: <Widget>[
                        Icon(e.icon, color: e.color),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                e.title,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                '${e.value}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _Stat {
  const _Stat(this.title, this.value, this.icon, {this.color});
  final String title;
  final int value;
  final IconData icon;
  final Color? color;
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
