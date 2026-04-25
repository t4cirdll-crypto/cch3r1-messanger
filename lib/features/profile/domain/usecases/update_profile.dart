import '../../../../core/usecases/usecase.dart';
import '../../../auth/domain/entities/profile_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateProfile extends UseCase<ProfileEntity, String> {
  const UpdateProfile(this._repo);
  final ProfileRepository _repo;

  @override
  Future<ProfileEntity> call(String displayName) =>
      _repo.updateDisplayName(displayName);
}
