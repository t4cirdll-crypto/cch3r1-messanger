import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/update_profile.dart';
import '../../domain/usecases/upload_avatar.dart';

final Provider<ProfileRemoteDataSource> profileRemoteDataSourceProvider =
    Provider<ProfileRemoteDataSource>(
  (Ref ref) => ProfileRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
  (Ref ref) => ProfileRepositoryImpl(
    remote: ref.watch(profileRemoteDataSourceProvider),
    client: ref.watch(supabaseClientProvider),
  ),
);

final Provider<UpdateProfile> updateProfileUseCaseProvider =
    Provider<UpdateProfile>(
  (Ref ref) => UpdateProfile(ref.watch(profileRepositoryProvider)),
);

final Provider<UploadAvatar> uploadAvatarUseCaseProvider =
    Provider<UploadAvatar>(
  (Ref ref) => UploadAvatar(ref.watch(profileRepositoryProvider)),
);
