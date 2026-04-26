import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/providers/app_settings_providers.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/usecases/update_profile.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _displayName = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  /// Скрытый bootstrap: 5 быстрых тапов по версии открывают экран device id.
  int _versionTapCount = 0;
  DateTime _lastVersionTap = DateTime.fromMillisecondsSinceEpoch(0);

  void _onVersionTap() {
    final DateTime now = DateTime.now();
    if (now.difference(_lastVersionTap) > const Duration(seconds: 2)) {
      _versionTapCount = 0;
    }
    _versionTapCount += 1;
    _lastVersionTap = now;
    if (_versionTapCount >= 5) {
      _versionTapCount = 0;
      context.push('/device-id');
    }
  }

  @override
  void dispose() {
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _hydrate(ProfileEntity p) {
    if (_initialized) return;
    _displayName.text = p.displayName ?? '';
    _bio.text = p.bio ?? '';
    _initialized = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final UpdateProfile useCase = ref.read(updateProfileUseCaseProvider);
      await useCase.call(UpdateProfileParams(
        displayName: _displayName.text,
        bio: _bio.text,
      ));
      ref.invalidate(authControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.profileSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.somethingWentWrong}: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _saving = true);
    try {
      final useCase = ref.read(uploadAvatarUseCaseProvider);
      await useCase.call(File(picked.path));
      ref.invalidate(authControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.avatarUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.somethingWentWrong}: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    await ref.read(themeModeControllerProvider.notifier).setThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ProfileEntity?> profileState =
        ref.watch(authControllerProvider);
    final ThemeMode currentTheme = ref
            .watch(themeModeControllerProvider)
            .valueOrNull ??
        ThemeMode.system;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileTitle)),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace _) => Center(child: Text('$err')),
        data: (ProfileEntity? p) {
          if (p == null) {
            return const Center(child: Text('Профиль не загружен'));
          }
          _hydrate(p);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 56,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                      backgroundImage: p.avatarUrl != null
                          ? CachedNetworkImageProvider(p.avatarUrl!)
                          : null,
                      child: p.avatarUrl == null
                          ? Text(
                              p.effectiveName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontSize: 36),
                            )
                          : null,
                    ),
                    FloatingActionButton.small(
                      heroTag: 'avatar-edit',
                      onPressed: _saving ? null : _pickAvatar,
                      child: const Icon(Icons.camera_alt_outlined),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                readOnly: true,
                controller: TextEditingController(text: '@${p.username}'),
                decoration: const InputDecoration(
                  labelText: AppStrings.usernameLabel,
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _displayName,
                decoration: const InputDecoration(
                  labelText: AppStrings.displayNameLabel,
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bio,
                minLines: 2,
                maxLines: 4,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: AppStrings.bioLabel,
                  hintText: AppStrings.bioHint,
                  prefixIcon: Icon(Icons.info_outline),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text(AppStrings.save),
              ),
              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  AppStrings.settingsTheme,
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              _ThemeOptionTile(
                title: AppStrings.themeSystem,
                icon: Icons.brightness_auto_outlined,
                selected: currentTheme == ThemeMode.system,
                onTap: () => _setThemeMode(ThemeMode.system),
              ),
              _ThemeOptionTile(
                title: AppStrings.themeLight,
                icon: Icons.light_mode_outlined,
                selected: currentTheme == ThemeMode.light,
                onTap: () => _setThemeMode(ThemeMode.light),
              ),
              _ThemeOptionTile(
                title: AppStrings.themeDark,
                icon: Icons.dark_mode_outlined,
                selected: currentTheme == ThemeMode.dark,
                onTap: () => _setThemeMode(ThemeMode.dark),
              ),
              const SizedBox(height: 24),
              // Админ-секция: видна только если текущий юзер + device — админ.
              Consumer(
                builder: (BuildContext _, WidgetRef ref, Widget? __) {
                  final AsyncValue<bool> isAdmin =
                      ref.watch(isAdminProvider);
                  if (isAdmin.valueOrNull != true) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: FilledButton.tonalIcon(
                      icon: const Icon(Icons.shield_outlined),
                      label: const Text('Открыть админку'),
                      onPressed: () => context.push('/admin'),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: const Text(AppStrings.signOut),
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _onVersionTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'cch3r1 messanger v0.1.0',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: selected ? cs.primary : null),
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check_circle, color: cs.primary)
          : Icon(Icons.circle_outlined,
              color: cs.outline.withValues(alpha: 0.5)),
      onTap: onTap,
    );
  }
}
