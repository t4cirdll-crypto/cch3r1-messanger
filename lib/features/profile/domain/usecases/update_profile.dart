import '../../../auth/domain/entities/profile_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateProfileParams {
  const UpdateProfileParams({this.displayName, this.bio});
  final String? displayName;
  final String? bio;
}

class UpdateProfile {
  const UpdateProfile(this._repo);
  final ProfileRepository _repo;

  Future<ProfileEntity> call(UpdateProfileParams params) =>
      _repo.updateProfile(displayName: params.displayName, bio: params.bio);
}
