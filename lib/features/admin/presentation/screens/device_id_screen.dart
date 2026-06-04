import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../providers/admin_providers.dart';

/// Скрытый экран: показывает Android device id, чтобы KillDev мог переслать
/// его и зарегистрировать как админский. Доступен через 5 быстрых тапов
/// по версии приложения в Профиле.
class DeviceIdScreen extends ConsumerWidget {
  const DeviceIdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AsyncValue<String> id = ref.watch(deviceIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Device ID')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: id.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object err, StackTrace _) => Center(child: Text('$err')),
          data: (String value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'ID этого устройства. Перешли его админу — он добавит '
                'устройство в список админских и активирует панель.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  boxShadow: AppShadows.sm(theme.brightness),
                ),
                child: SelectableText(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Скопировать'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Скопировано')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
