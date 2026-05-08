import 'package:flutter/foundation.dart';

@immutable
class ProfileEntity {
  const ProfileEntity({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  String get effectiveName {
    final String? name = displayName?.trim();
    if (_isPyatochki(name)) return 'Пяточки';
    return name != null && name.isNotEmpty ? name : username;
  }

  bool _isPyatochki(String? name) {
    final String normalizedUsername = username.trim().toLowerCase();
    final String normalizedName = (name ?? '').trim().toLowerCase();
    return normalizedUsername == 'pyatocki' ||
        normalizedUsername == 'pyatochki' ||
        normalizedName == 'пятокчи' ||
        normalizedName == 'пяточчи' ||
        normalizedName == 'пяточки';
  }

  ProfileEntity copyWith({
    String? id,
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProfileEntity &&
          id == other.id &&
          username == other.username &&
          displayName == other.displayName &&
          bio == other.bio &&
          avatarUrl == other.avatarUrl &&
          isOnline == other.isOnline &&
          lastSeen == other.lastSeen);

  @override
  int get hashCode =>
      Object.hash(id, username, displayName, bio, avatarUrl, isOnline, lastSeen);
}
