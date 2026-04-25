import '../../../../core/usecases/usecase.dart';
import '../entities/profile_entity.dart';
import '../repositories/auth_repository.dart';

class GetCurrentProfile extends UseCase<ProfileEntity?, NoParams> {
  const GetCurrentProfile(this._repo);
  final AuthRepository _repo;

  @override
  Future<ProfileEntity?> call(NoParams params) => _repo.getCurrentProfile();
}
