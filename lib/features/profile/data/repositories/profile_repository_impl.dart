import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart' as app;
import '../../../auth/domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required this.remote, required this.client});

  final ProfileRemoteDataSource remote;
  final SupabaseClient client;

  String get _uid {
    final User? u = client.auth.currentUser;
    if (u == null) throw const app.AuthException('Нет активной сессии');
    return u.id;
  }

  @override
  Future<ProfileEntity> updateProfile({
    String? displayName,
    String? bio,
  }) async {
    return (await remote.updateProfile(
      userId: _uid,
      displayName: displayName,
      bio: bio,
    ))
        .toEntity();
  }

  @override
  Future<String> uploadAvatar(File file) =>
      remote.uploadAvatar(userId: _uid, file: file);
}
