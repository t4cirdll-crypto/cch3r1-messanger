import 'dart:io';

import '../../../auth/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<ProfileEntity> updateDisplayName(String displayName);
  Future<String> uploadAvatar(File file);
}
