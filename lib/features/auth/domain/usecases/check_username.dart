import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

class CheckUsername extends UseCase<bool, String> {
  const CheckUsername(this._repo);
  final AuthRepository _repo;

  @override
  Future<bool> call(String username) => _repo.isUsernameAvailable(username);
}
