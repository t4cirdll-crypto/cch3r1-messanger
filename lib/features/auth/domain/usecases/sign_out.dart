import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

class SignOut extends UseCase<void, NoParams> {
  const SignOut(this._repo);
  final AuthRepository _repo;

  @override
  Future<void> call(NoParams params) => _repo.signOut();
}
