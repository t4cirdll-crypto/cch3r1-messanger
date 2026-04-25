import 'package:sqflite/sqflite.dart';

import '../../../../core/db/local_database.dart';
import '../models/profile_model.dart';

/// Локальный кэш профиля текущего пользователя.
class AuthLocalDataSource {
  AuthLocalDataSource(this._db);

  final LocalDatabase _db;

  Future<void> cacheProfile(ProfileModel profile) async {
    await _db.db.insert(
      'profiles',
      profile.toDb(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ProfileModel?> getProfile(String id) async {
    final List<Map<String, Object?>> rows = await _db.db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ProfileModel.fromDb(rows.first);
  }

  Future<void> clear() async {
    await _db.db.delete('profiles');
    await _db.db.delete('conversations');
    await _db.db.delete('messages');
  }
}
