import 'dart:io';

import '../../../auth/domain/entities/profile_entity.dart';

abstract class ProfileRepository {
  /// Обновляет произвольный набор полей профиля (display_name / bio).
  /// `null` означает «не трогать поле».
  Future<ProfileEntity> updateProfile({
    String? displayName,
    String? bio,
  });

  Future<String> uploadAvatar(File file);
}
