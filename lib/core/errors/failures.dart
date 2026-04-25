import 'package:flutter/foundation.dart';

/// Абстракция ошибки для presentation-слоя (дружественное сообщение).
@immutable
sealed class Failure {
  const Failure(this.message);
  final String message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Нет подключения к сети']);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class UsernameTakenFailure extends Failure {
  const UsernameTakenFailure() : super('Этот ник уже занят');
}

class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure() : super('Неверный ник или пароль');
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Что-то пошло не так']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Ошибка локального хранилища']);
}
