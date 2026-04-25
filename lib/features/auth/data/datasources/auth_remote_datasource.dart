import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../config/supabase_config.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/username_mapper.dart';
import '../models/profile_model.dart';

/// Удалённый датасорс аутентификации.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final sb.SupabaseClient _client;

  Future<bool> isUsernameAvailable(String username) async {
    final String normalized = UsernameMapper.normalize(username);
    try {
      final dynamic response = await _client.functions.invoke(
        SupabaseConfig.checkUsernameFunction,
        body: <String, String>{'username': normalized},
      );
      final Map<String, dynamic>? data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : null;
      if (data == null) {
        throw const NetworkException('Некорректный ответ check-username');
      }
      if (data['error'] == 'invalid_format') {
        throw const AuthException('Некорректный формат ника');
      }
      return data['available'] == true;
    } on sb.FunctionException catch (e) {
      throw NetworkException('check-username: ${e.details}');
    }
  }

  Future<ProfileModel> signUp({
    required String username,
    required String password,
  }) async {
    final String normalized = UsernameMapper.normalize(username);
    final String email = UsernameMapper.toEmail(normalized);
    try {
      final sb.AuthResponse res = await _client.auth.signUp(
        email: email,
        password: password,
        data: <String, dynamic>{'username': normalized},
      );
      final sb.User? user = res.user;
      if (user == null) {
        throw const AuthException('Не удалось создать пользователя');
      }
      // Страховка: если триггер не отработал (например, в локальном Supabase),
      // пытаемся создать запись вручную.
      await _client.from('profiles').upsert(<String, dynamic>{
        'id': user.id,
        'username': normalized,
      }, onConflict: 'id');

      return _fetchProfile(user.id);
    } on sb.AuthException catch (e) {
      if (e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('duplicate')) {
        throw const UsernameTakenException();
      }
      throw AuthException(e.message, cause: e);
    }
  }

  Future<ProfileModel> signIn({
    required String username,
    required String password,
  }) async {
    final String email = UsernameMapper.toEmail(username);
    try {
      final sb.AuthResponse res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final sb.User? user = res.user;
      if (user == null) {
        throw const AuthException('Неверный ник или пароль');
      }
      return _fetchProfile(user.id);
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, cause: e);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<ProfileModel?> getCurrentProfile() async {
    final sb.User? user = _client.auth.currentUser;
    if (user == null) return null;
    return _fetchProfile(user.id);
  }

  Future<ProfileModel> _fetchProfile(String id) async {
    final Map<String, dynamic> row = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .single();
    return ProfileModel.fromJson(row);
  }

  Future<void> setOnline(bool online) async {
    final sb.User? user = _client.auth.currentUser;
    if (user == null) return;
    await _client.from('profiles').update(<String, dynamic>{
      'is_online': online,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', user.id);
  }
}
