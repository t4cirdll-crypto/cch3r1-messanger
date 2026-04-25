import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/profile_entity.dart';

part 'profile_model.freezed.dart';
part 'profile_model.g.dart';

/// DTO для таблицы `profiles`.
@freezed
class ProfileModel with _$ProfileModel {
  const ProfileModel._();

  const factory ProfileModel({
    required String id,
    required String username,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @Default(false) @JsonKey(name: 'is_online') bool isOnline,
    @JsonKey(name: 'last_seen') DateTime? lastSeen,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _ProfileModel;

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);

  /// Преобразование модели БД (sqflite).
  factory ProfileModel.fromDb(Map<String, Object?> row) => ProfileModel(
        id: row['id']! as String,
        username: row['username']! as String,
        displayName: row['display_name'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        isOnline: ((row['is_online'] as int?) ?? 0) == 1,
        lastSeen: row['last_seen'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['last_seen']! as int),
        createdAt: row['created_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      );

  Map<String, Object?> toDb() => <String, Object?>{
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'is_online': isOnline ? 1 : 0,
        'last_seen': lastSeen?.millisecondsSinceEpoch,
        'created_at': createdAt?.millisecondsSinceEpoch,
      };

  ProfileEntity toEntity() => ProfileEntity(
        id: id,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        isOnline: isOnline,
        lastSeen: lastSeen,
        createdAt: createdAt,
      );
}
