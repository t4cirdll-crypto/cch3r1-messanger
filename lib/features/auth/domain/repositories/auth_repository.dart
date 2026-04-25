import '../entities/profile_entity.dart';

abstract class AuthRepository {
  /// Проверка уникальности ника через Edge Function.
  Future<bool> isUsernameAvailable(String username);

  /// Регистрация: создание пользователя + запись в profiles.
  Future<ProfileEntity> signUp({
    required String username,
    required String password,
  });

  Future<ProfileEntity> signIn({
    required String username,
    required String password,
  });

  Future<void> signOut();

  /// Профиль текущего пользователя (или null если не залогинен).
  Future<ProfileEntity?> getCurrentProfile();

  /// Установить онлайн-статус текущего пользователя.
  Future<void> setOnline(bool online);
}
