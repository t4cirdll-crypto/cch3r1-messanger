import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../search_user/presentation/providers/search_providers.dart';
import '../../domain/entities/conversation_entity.dart';
import '../providers/chat_list_providers.dart';

/// Экран создания группового чата:
///  1. Выбор участников (мультивыбор + поиск).
///  2. Ввод названия группы.
///  3. Создание группы через `fn_create_group`.
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  Timer? _debounce;
  final Map<String, ProfileEntity> _selected = <String, ProfileEntity>{};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Сбрасываем поисковый запрос на вход.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchQueryProvider.notifier).state = '';
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  void _toggleSelect(ProfileEntity p) {
    setState(() {
      if (_selected.containsKey(p.id)) {
        _selected.remove(p.id);
      } else {
        _selected[p.id] = p;
      }
    });
  }

  Future<void> _submit() async {
    final String title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название группы')),
      );
      return;
    }
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одного участника')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final ConversationEntity conv = await ref
          .read(chatListControllerProvider.notifier)
          .createGroup(
            title: title,
            memberIds: _selected.keys.toList(),
          );
      if (!mounted) return;
      context.pushReplacement('/chat/${conv.id}', extra: conv);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.somethingWentWrong}: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<ProfileEntity>> results =
        ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая группа'),
        actions: <Widget>[
          IconButton(
            icon: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            tooltip: 'Создать',
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _titleCtrl,
              maxLength: 64,
              decoration: const InputDecoration(
                labelText: 'Название группы',
                prefixIcon: Icon(Icons.group),
              ),
            ),
          ),
          if (_selected.isNotEmpty)
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _selected.values
                    .map((ProfileEntity p) => _SelectedChip(
                          profile: p,
                          onRemove: () => _toggleSelect(p),
                        ))
                    .toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: AppStrings.searchHint,
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Выбрано: ${_selected.length}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: results.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (Object err, StackTrace _) =>
                  Center(child: Text('$err')),
              data: (List<ProfileEntity> users) {
                if (users.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Найдите пользователей по нику и отметьте их.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext _, int i) {
                    final ProfileEntity p = users[i];
                    final bool selected = _selected.containsKey(p.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (_) => _toggleSelect(p),
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: CircleAvatar(
                        radius: 22,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        backgroundImage: p.avatarUrl != null
                            ? CachedNetworkImageProvider(p.avatarUrl!)
                            : null,
                        child: p.avatarUrl == null
                            ? Text(
                                p.effectiveName.isEmpty
                                    ? '?'
                                    : p.effectiveName
                                        .substring(0, 1)
                                        .toUpperCase(),
                              )
                            : null,
                      ),
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
    );
  }
}

class _SelectedChip extends StatelessWidget {
  const _SelectedChip({required this.profile, required this.onRemove});

  final ProfileEntity profile;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: <Widget>[
          Stack(
            children: <Widget>[
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: profile.avatarUrl != null
                    ? CachedNetworkImageProvider(profile.avatarUrl!)
                    : null,
                child: profile.avatarUrl == null
                    ? Text(
                        profile.effectiveName.isEmpty
                            ? '?'
                            : profile.effectiveName
                                .substring(0, 1)
                                .toUpperCase(),
                      )
                    : null,
              ),
              Positioned(
                top: -4,
                right: -4,
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: theme.colorScheme.error,
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: theme.colorScheme.onError,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 56,
            child: Text(
              profile.effectiveName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
