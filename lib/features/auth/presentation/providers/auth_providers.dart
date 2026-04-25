import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/local_database.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../../../core/usecases/usecase.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/check_username.dart';
import '../../domain/usecases/get_current_profile.dart';
import '../../domain/usecases/sign_in.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up.dart';

final Provider<AuthRemoteDataSource> authRemoteDataSourceProvider =
    Provider<AuthRemoteDataSource>(
  (Ref ref) => AuthRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final FutureProvider<AuthLocalDataSource> authLocalDataSourceProvider =
    FutureProvider<AuthLocalDataSource>((Ref ref) async {
  final LocalDatabase db = await ref.watch(localDatabaseProvider);
  return AuthLocalDataSource(db);
});

final FutureProvider<AuthRepository> authRepositoryProvider =
    FutureProvider<AuthRepository>((Ref ref) async {
  final AuthLocalDataSource local = await ref.watch(authLocalDataSourceProvider.future);
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    local: local,
  );
});

final FutureProvider<SignUp> signUpUseCaseProvider = FutureProvider<SignUp>(
  (Ref ref) async => SignUp(await ref.watch(authRepositoryProvider.future)),
);
final FutureProvider<SignIn> signInUseCaseProvider = FutureProvider<SignIn>(
  (Ref ref) async => SignIn(await ref.watch(authRepositoryProvider.future)),
);
final FutureProvider<SignOut> signOutUseCaseProvider = FutureProvider<SignOut>(
  (Ref ref) async => SignOut(await ref.watch(authRepositoryProvider.future)),
);
final FutureProvider<CheckUsername> checkUsernameUseCaseProvider =
    FutureProvider<CheckUsername>(
  (Ref ref) async => CheckUsername(await ref.watch(authRepositoryProvider.future)),
);
final FutureProvider<GetCurrentProfile> getCurrentProfileUseCaseProvider =
    FutureProvider<GetCurrentProfile>(
  (Ref ref) async => GetCurrentProfile(await ref.watch(authRepositoryProvider.future)),
);

/// Контроллер аутентификации. Держит текущий профиль как AsyncValue.
class AuthController extends AsyncNotifier<ProfileEntity?> {
  @override
  Future<ProfileEntity?> build() async {
    // Перестраиваемся при изменении сессии.
    ref.watch(currentSessionProvider);
    final String? userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    final GetCurrentProfile uc =
        await ref.watch(getCurrentProfileUseCaseProvider.future);
    return uc.call(const NoParams());
  }

  Future<void> signIn({required String username, required String password}) async {
    state = const AsyncLoading<ProfileEntity?>();
    state = await AsyncValue.guard(() async {
      final SignIn uc = await ref.read(signInUseCaseProvider.future);
      return uc.call(SignInParams(username: username, password: password));
    });
  }

  Future<void> signUp({required String username, required String password}) async {
    state = const AsyncLoading<ProfileEntity?>();
    state = await AsyncValue.guard(() async {
      final SignUp uc = await ref.read(signUpUseCaseProvider.future);
      return uc.call(SignUpParams(username: username, password: password));
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading<ProfileEntity?>();
    state = await AsyncValue.guard(() async {
      final SignOut uc = await ref.read(signOutUseCaseProvider.future);
      await uc.call(const NoParams());
      return null;
    });
  }

  Future<bool> checkUsername(String username) async {
    final CheckUsername uc =
        await ref.read(checkUsernameUseCaseProvider.future);
    return uc.call(username);
  }
}

final AsyncNotifierProvider<AuthController, ProfileEntity?> authControllerProvider =
    AsyncNotifierProvider<AuthController, ProfileEntity?>(AuthController.new);
