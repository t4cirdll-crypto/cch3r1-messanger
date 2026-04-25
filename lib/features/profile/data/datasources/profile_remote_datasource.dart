import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/supabase_config.dart';
import '../../../auth/data/models/profile_model.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<ProfileModel> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
  }) async {
    final Map<String, dynamic> patch = <String, dynamic>{};
    if (displayName != null) {
      patch['display_name'] = displayName.trim();
    }
    if (bio != null) {
      final String trimmed = bio.trim();
      patch['bio'] = trimmed.isEmpty ? null : trimmed;
    }
    if (patch.isEmpty) {
      final Map<String, dynamic> row =
          await _client.from('profiles').select().eq('id', userId).single();
      return ProfileModel.fromJson(row);
    }
    final Map<String, dynamic> row = await _client
        .from('profiles')
        .update(patch)
        .eq('id', userId)
        .select()
        .single();
    return ProfileModel.fromJson(row);
  }

  Future<String> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    final String ext = file.path.split('.').last.toLowerCase();
    final String path =
        '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(SupabaseConfig.avatarsBucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    final String publicUrl =
        _client.storage.from(SupabaseConfig.avatarsBucket).getPublicUrl(path);
    await _client
        .from('profiles')
        .update(<String, dynamic>{'avatar_url': publicUrl})
        .eq('id', userId);
    return publicUrl;
  }
}
