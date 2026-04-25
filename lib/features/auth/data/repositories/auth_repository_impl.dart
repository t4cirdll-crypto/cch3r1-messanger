import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remote,
    required this.local,
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;

  @override
  Future<bool> isUsernameAvailable(String username) {
    return remote.isUsernameAvailable(username);
  }

  @override
  Future<ProfileEntity> signUp({
    required String username,
    required String password,
  }) async {
    final bool available = await remote.isUsernameAvailable(username);
    if (!available) throw const UsernameTakenException();
    final ProfileEntity profile = (await remote.signUp(
      username: username,
      password: password,
    )).toEntity();
    await local.cacheProfile((await remote.getCurrentProfile())!);
    return profile;
  }

  @override
  Future<ProfileEntity> signIn({
    required String username,
    required String password,
  }) async {
    final ProfileEntity profile = (await remote.signIn(
      username: username,
      password: password,
    )).toEntity();
    await local.cacheProfile((await remote.getCurrentProfile())!);
    return profile;
  }

  @override
  Future<void> signOut() async {
    await remote.setOnline(false);
    await remote.signOut();
    await local.clear();
  }

  @override
  Future<ProfileEntity?> getCurrentProfile() async {
    try {
      final profile = await remote.getCurrentProfile();
      if (profile != null) {
        await local.cacheProfile(profile);
        return profile.toEntity();
      }
    } catch (_) {
      // Офлайн: берём из кэша если есть.
    }
    return null;
  }

  @override
  Future<void> setOnline(bool online) => remote.setOnline(online);
}
