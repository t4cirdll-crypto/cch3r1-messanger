import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/admin_providers.dart';

/// Скрытый экран: показывает Android device id, чтобы KillDev мог переслать
/// его и зарегистрировать как админский. Доступен через 5 быстрых тапов
/// по версии приложения в Профиле.
class DeviceIdScreen extends ConsumerWidget {
  const DeviceIdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String> id = ref.watch(deviceIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Device ID')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: id.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object err, StackTrace _) => Center(child: Text('$err')),
          data: (String value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'ID этого устройства. Перешли его админу — он добавит '
                'устройство в список админских и активирует панель.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  value,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
