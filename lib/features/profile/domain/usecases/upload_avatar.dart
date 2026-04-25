import 'dart:io';

import '../../../../core/usecases/usecase.dart';
import '../repositories/profile_repository.dart';

class UploadAvatar extends UseCase<String, File> {
  const UploadAvatar(this._repo);
  final ProfileRepository _repo;

  @override
  Future<String> call(File file) => _repo.uploadAvatar(file);
}
