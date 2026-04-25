import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Экземпляр Supabase клиента.
final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) => Supabase.instance.client);

/// Стрим состояний аутентификации.
final StreamProvider<AuthState> authStateChangesProvider =
    StreamProvider<AuthState>((Ref ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// Текущая сессия Supabase (пересчитывается при изменениях).
final Provider<Session?> currentSessionProvider = Provider<Session?>((Ref ref) {
  final AsyncValue<AuthState> state = ref.watch(authStateChangesProvider);
  return state.when(
    data: (AuthState value) => value.session,
    loading: () => ref.read(supabaseClientProvider).auth.currentSession,
    error: (_, __) => ref.read(supabaseClientProvider).auth.currentSession,
  );
});

/// Текущий id пользователя (null, если не залогинен).
final Provider<String?> currentUserIdProvider = Provider<String?>((Ref ref) {
  return ref.watch(currentSessionProvider)?.user.id;
});
