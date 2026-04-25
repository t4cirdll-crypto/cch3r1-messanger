/// Низкоуровневые исключения: бросаются в data-слое и ловятся в репозитории.
class AppException implements Exception {
  const AppException(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException($message)';
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Нет подключения к серверу']);
}

class AuthException extends AppException {
  const AuthException(super.message, {super.cause});
}

class UsernameTakenException extends AppException {
  const UsernameTakenException() : super('Ник уже занят');
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Не найдено']);
}

class CacheException extends AppException {
  const CacheException(super.message, {super.cause});
}
