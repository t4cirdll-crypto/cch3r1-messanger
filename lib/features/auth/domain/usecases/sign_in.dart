import '../../../../core/usecases/usecase.dart';
import '../entities/profile_entity.dart';
import '../repositories/auth_repository.dart';

class SignInParams {
  const SignInParams({required this.username, required this.password});
  final String username;
  final String password;
}

class SignIn extends UseCase<ProfileEntity, SignInParams> {
  const SignIn(this._repo);
  final AuthRepository _repo;

  @override
  Future<ProfileEntity> call(SignInParams params) =>
      _repo.signIn(username: params.username, password: params.password);
}
