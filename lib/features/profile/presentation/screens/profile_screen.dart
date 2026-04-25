import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _displayName = TextEditingController();
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  void _hydrate(ProfileEntity p) {
    if (_initialized) return;
    _displayName.text = p.displayName ?? '';
    _initialized = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final useCase = ref.read(updateProfileUseCaseProvider);
      await useCase.call(_displayName.text);
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

  @override
  Widget build(BuildContext context) {
    final AsyncValue<ProfileEntity?> profileState =
        ref.watch(authControllerProvider);

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
              const SizedBox(height: 24),
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _signOut,
                icon: const Icon(Icons.logout),
                label: const Text(AppStrings.signOut),
              ),
            ],
          );
        },
      ),
    );
  }
}
