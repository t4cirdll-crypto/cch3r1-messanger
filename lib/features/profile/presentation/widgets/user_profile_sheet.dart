import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../chat_list/domain/entities/conversation_entity.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../chat_list/presentation/providers/chat_list_providers.dart';
import '../../../admin/data/admin_repository.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../providers/profile_providers.dart';

final AutoDisposeFutureProviderFamily<bool, String> userIsBannedProvider =
    FutureProvider.autoDispose.family<bool, String>((Ref ref, String userId) async {
  final client = ref.watch(supabaseClientProvider);
  final response =
      await client.from('profiles').select('is_banned').eq('id', userId).single();
  return response['is_banned'] == true;
});

class UserProfileSheet extends ConsumerWidget {
  const UserProfileSheet({
    super.key,
    required this.userId,
  });

  final String userId;

  static void show(BuildContext context, String userId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => UserProfileSheet(userId: userId),
    );
  }

  Future<void> _startConversation(BuildContext context, WidgetRef ref) async {
    try {
      final useCase =
          await ref.read(createOrGetConversationUseCaseProvider.future);
      final ConversationEntity conv = await useCase.call(userId);
      if (!context.mounted) return;
      // Close sheet
      Navigator.pop(context);
      // Navigate to chat
      context.push('/chat/${conv.id}', extra: conv);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.somethingWentWrong}: $e')),
      );
    }
  }

  Color _getRankColor(String rank, ColorScheme cs) {
    final String r = rank.toUpperCase();
    if (r == 'BOT' || r == 'БОТ') return Colors.purple;
    if (r == 'ADMIN' || r == 'АДМИН') return Colors.red;
    if (r == 'MODERATOR' || r == 'МОДЕР') return Colors.blue;
    if (r == 'VIP' || r == 'ВИП') return Colors.amber;
    if (r == 'DEV' || r == 'РАЗРАБ') return Colors.green;
    return cs.primary;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProfileEntity> profileState =
        ref.watch(userProfileProvider(userId));
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          profileState.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object error, StackTrace _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    'Не удалось загрузить профиль: $error',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            data: (ProfileEntity profile) {
              final String initials = profile.effectiveName.isNotEmpty
                  ? profile.effectiveName.substring(0, 1).toUpperCase()
                  : '?';

              return Column(
                children: <Widget>[
                  // Avatar and User details
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: <Widget>[
                        UserAvatar(
                          radius: 56,
                          initial: initials,
                          avatarUrl: profile.avatarUrl,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                profile.effectiveName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profile.rank != null && profile.rank!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getRankColor(profile.rank!, cs)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getRankColor(profile.rank!, cs)
                                        .withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  profile.rank!.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _getRankColor(profile.rank!, cs),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile.isOnline
                              ? AppStrings.online
                              : profile.lastSeen == null
                                  ? 'офлайн'
                                  : AppStrings.lastSeen(
                                      DateFormatter.lastSeenAgo(profile.lastSeen!),
                                    ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: profile.isOnline
                                ? Colors.green
                                : cs.onSurfaceVariant,
                            fontWeight: profile.isOnline
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  // Information List
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.alternate_email),
                        title: Text('@${profile.username}'),
                        subtitle: const Text('Имя пользователя'),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Скопировать username',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: '@${profile.username}'),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Имя пользователя скопировано'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ),
                      if (profile.bio != null && profile.bio!.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: Text(profile.bio!),
                          subtitle: const Text('О себе'),
                        ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 20),
                  // Message Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _startConversation(context, ref),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text(
                          'Написать сообщение',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Admin panel if the viewer is an admin
                  Consumer(
                    builder: (BuildContext context, WidgetRef ref, Widget? _) {
                      final bool isCallerAdmin =
                          ref.watch(isAdminProvider).valueOrNull ?? false;
                      if (!isCallerAdmin) return const SizedBox.shrink();

                      final AsyncValue<bool> isBannedState =
                          ref.watch(userIsBannedProvider(profile.id));

                      return isBannedState.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (bool isBanned) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.shield_outlined,
                                      color: cs.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Администрирование',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  ActionChip(
                                    avatar:
                                        const Icon(Icons.badge_outlined, size: 16),
                                    label: Text(profile.rank == null ||
                                            profile.rank!.isEmpty
                                        ? 'Выдать ранг'
                                        : 'Ранг: ${profile.rank}'),
                                    onPressed: () async {
                                      final String? newRank = await _askText(
                                        context,
                                        'Укажите ранг (например, БОТ, VIP, ADMIN или пусто для сброса)',
                                        initial: profile.rank ?? '',
                                      );
                                      if (newRank == null) return;
                                      final AdminRepository repo =
                                          ref.read(adminRepositoryProvider);
                                      await repo.setRank(
                                          userId: profile.id,
                                          rank:
                                              newRank.isEmpty ? null : newRank);
                                      ref.invalidate(userProfileProvider(userId));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Ранг успешно обновлен')),
                                        );
                                      }
                                    },
                                  ),
                                  ActionChip(
                                    avatar: Icon(
                                      isBanned ? Icons.lock_open : Icons.block,
                                      size: 16,
                                      color: isBanned ? Colors.green : Colors.red,
                                    ),
                                    label: Text(
                                      isBanned ? 'Разбанить' : 'Забанить',
                                      style: TextStyle(
                                        color: isBanned ? Colors.green : Colors.red,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final AdminRepository repo =
                                          ref.read(adminRepositoryProvider);
                                      if (isBanned) {
                                        await repo.setBanned(
                                            userId: profile.id, banned: false);
                                        ref.invalidate(
                                            userIsBannedProvider(profile.id));
                                        ref.invalidate(userProfileProvider(userId));
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('Пользователь разбанен')),
                                          );
                                        }
                                      } else {
                                        final String? reason = await _askText(
                                          context,
                                          'Причина бана (необязательно)',
                                          initial: '',
                                        );
                                        if (reason == null) return;
                                        await repo.setBanned(
                                            userId: profile.id,
                                            banned: true,
                                            reason: reason);
                                        ref.invalidate(
                                            userIsBannedProvider(profile.id));
                                        ref.invalidate(userProfileProvider(userId));
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content:
                                                    Text('Пользователь забанен')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                  ActionChip(
                                    avatar: const Icon(Icons.password, size: 16),
                                    label: const Text('Сброс пароля'),
                                    onPressed: () async {
                                      final String? pwd = await _askText(
                                        context,
                                        'Новый пароль (мин. 6 символов)',
                                        initial: '',
                                      );
                                      if (pwd == null) return;
                                      if (pwd.length < 6) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Пароль слишком короткий')),
                                          );
                                        }
                                        return;
                                      }
                                      final AdminRepository repo =
                                          ref.read(adminRepositoryProvider);
                                      await repo.resetPassword(
                                          userId: profile.id, newPassword: pwd);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Пароль успешно сброшен')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
