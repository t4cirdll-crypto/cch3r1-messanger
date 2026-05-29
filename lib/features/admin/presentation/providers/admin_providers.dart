import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/services/device_id_service.dart';
import '../../data/admin_repository.dart';
import '../../domain/entities/admin_entities.dart';

final Provider<AdminRepository> adminRepositoryProvider =
    Provider<AdminRepository>(
  (Ref ref) => AdminRepository(ref.watch(supabaseClientProvider)),
);

/// Текущий device id (Android ID и т.п.).
final FutureProvider<String> deviceIdProvider =
    FutureProvider<String>((Ref ref) => DeviceIdService.get());

/// Проверка: является ли текущая комбинация (auth user + device) админом.
/// На сервере проверяем что caller есть в `app_admins`, а на клиенте
/// дополнительно сверяем device_id, чтобы UI не светился на других устройствах.
final FutureProvider<bool> isAdminProvider = FutureProvider<bool>(
  (Ref ref) async {
    final AdminRepository repo = ref.watch(adminRepositoryProvider);
    final bool serverAdmin = await repo.isAdmin();
    if (!serverAdmin) return false;

    // Сверяем device_id на клиенте для дополнительной защиты
    final String? serverDevId = await repo.selfDeviceId();
    if (serverDevId == null) return false;

    final String localDevId = await ref.watch(deviceIdProvider.future);
    return serverDevId == localDevId;
  },
);

final AutoDisposeFutureProvider<AdminStats> adminStatsProvider =
    FutureProvider.autoDispose<AdminStats>((Ref ref) async {
  final AdminRepository repo = ref.watch(adminRepositoryProvider);
  return repo.stats();
});

final AutoDisposeFutureProvider<List<AdminUser>> adminUsersProvider =
    FutureProvider.autoDispose<List<AdminUser>>((Ref ref) async {
  final AdminRepository repo = ref.watch(adminRepositoryProvider);
  return repo.users();
});

final AutoDisposeFutureProvider<List<AdminConversation>>
    adminConversationsProvider =
    FutureProvider.autoDispose<List<AdminConversation>>((Ref ref) async {
  final AdminRepository repo = ref.watch(adminRepositoryProvider);
  return repo.conversations();
});

final AutoDisposeFutureProviderFamily<List<AdminMessage>, String>
    adminMessagesProvider = FutureProvider.autoDispose
        .family<List<AdminMessage>, String>((Ref ref, String convId) async {
  final AdminRepository repo = ref.watch(adminRepositoryProvider);
  return repo.messages(convId);
});
