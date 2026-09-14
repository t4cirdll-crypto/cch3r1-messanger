import 'package:sqflite/sqflite.dart';

import '../../../../core/db/local_database.dart';
import '../models/profile_model.dart';

/// Локальный кэш профиля текущего пользователя.
class AuthLocalDataSource {
  AuthLocalDataSource(this._db);

  final LocalDatabase _db;

  Future<void> cacheProfile(String accountId, ProfileModel profile) async {
    final Map<String, Object?> row = <String, Object?>{
      'account_id': accountId,
      ...profile.toDb(),
    };
    await _db.db.insert(
      'profiles',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ProfileModel?> getProfile(String accountId, String id) async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'profiles',
      where: 'account_id = ? AND id = ?',
      whereArgs: <Object>[accountId, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProfileModel.fromDb(rows.first);
  }

  Future<void> clear(String accountId) async {
    await _db.clearCachedData(accountId);
  }
}
