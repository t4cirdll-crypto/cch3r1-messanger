import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/data/models/profile_model.dart';
import '../../../auth/domain/entities/profile_entity.dart';

/// Поисковый запрос (debounced на UI).
final StateProvider<String> searchQueryProvider =
    StateProvider<String>((Ref ref) => '');

final AutoDisposeFutureProvider<List<ProfileEntity>> searchResultsProvider =
    FutureProvider.autoDispose<List<ProfileEntity>>((Ref ref) async {
  final String q = ref.watch(searchQueryProvider).trim();
  if (q.length < 2) return <ProfileEntity>[];

  final client = ref.watch(supabaseClientProvider);
  final String? uid = ref.watch(currentUserIdProvider);

  final List<dynamic> rows = await client
      .from('profiles')
      .select()
      .ilike('username', '%$q%')
      .neq('id', uid ?? '')
      .limit(30);

  return rows
      .cast<Map<String, dynamic>>()
      .map(ProfileModel.fromJson)
      .map((ProfileModel m) => m.toEntity())
      .toList();
});
