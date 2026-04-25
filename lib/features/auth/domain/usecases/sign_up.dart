import '../../../../core/usecases/usecase.dart';
import '../entities/profile_entity.dart';
import '../repositories/auth_repository.dart';

class SignUpParams {
  const SignUpParams({required this.username, required this.password});
  final String username;
  final String password;
}

class SignUp extends UseCase<ProfileEntity, SignUpParams> {
  const SignUp(this._repo);
  final AuthRepository _repo;

  @override
  Future<ProfileEntity> call(SignUpParams params) =>
      _repo.signUp(username: params.username, password: params.password);
}
