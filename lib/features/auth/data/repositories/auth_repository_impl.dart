import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.remote,
    required this.local,
    String? Function()? currentAccountId,
  }) : _currentAccountId = currentAccountId ?? _currentAccountIdFromSupabase;

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;
  final String? Function() _currentAccountId;

  static String? _currentAccountIdFromSupabase() =>
      sb.Supabase.instance.client.auth.currentUser?.id;

  String get _uid {
    final String? accountId = _currentAccountId();
    if (accountId == null) {
      throw const AuthException('Нет активной сессии');
    }
    return accountId;
  }

  void _ensureCurrentAccount(String accountId) {
    if (_currentAccountId() != accountId) {
      throw const AuthException('Сессия изменилась');
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username) {
    return remote.isUsernameAvailable(username);
  }

  @override
  Future<ProfileEntity> signUp({
    required String username,
    required String password,
  }) async {
    final String? initialAccountId = _currentAccountId();
    final bool available = await remote.isUsernameAvailable(username);
    if (_currentAccountId() != initialAccountId) {
      throw const AuthException('Сессия изменилась');
    }
    if (!available) throw const UsernameTakenException();
    final profile = await remote.signUp(
      username: username,
      password: password,
    );
    final String accountId = profile.id;
    _ensureCurrentAccount(accountId);
    await local.cacheProfile(accountId, profile);
    _ensureCurrentAccount(accountId);
    return profile.toEntity();
  }

  @override
  Future<ProfileEntity> signIn({
    required String username,
    required String password,
  }) async {
    final profile = await remote.signIn(
      username: username,
      password: password,
    );
    final String accountId = profile.id;
    _ensureCurrentAccount(accountId);
    await local.cacheProfile(accountId, profile);
    _ensureCurrentAccount(accountId);
    return profile.toEntity();
  }

  @override
  Future<void> signOut() async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.setOnline(false);
    _ensureCurrentAccount(accountId);
    await remote.signOut();
    await local.clear(accountId);
  }

  @override
  Future<ProfileEntity?> getCurrentProfile() async {
    final String accountId = _uid;
    try {
      final profile = await remote.getCurrentProfile();
      _ensureCurrentAccount(accountId);
      if (profile == null) return null;
      if (profile.id != accountId) {
        throw const AuthException('Сессия изменилась');
      }
      await local.cacheProfile(accountId, profile);
      _ensureCurrentAccount(accountId);
      return profile.toEntity();
    } on AuthException {
      rethrow;
    } catch (_) {
      _ensureCurrentAccount(accountId);
      final profile = await local.getProfile(accountId, accountId);
      _ensureCurrentAccount(accountId);
      return profile?.toEntity();
    }
  }

  @override
  Future<void> setOnline(bool online) async {
    final String accountId = _uid;
    _ensureCurrentAccount(accountId);
    await remote.setOnline(online);
    _ensureCurrentAccount(accountId);
  }
}
