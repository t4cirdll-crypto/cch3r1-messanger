import 'package:flutter/foundation.dart';

@immutable
class ProfileEntity {
  const ProfileEntity({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.isOnline = false,
    this.lastSeen,
    this.createdAt,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? createdAt;

  String get effectiveName =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!
          : username;

  ProfileEntity copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? createdAt,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
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
          avatarUrl == other.avatarUrl &&
          isOnline == other.isOnline &&
          lastSeen == other.lastSeen);

  @override
  int get hashCode => Object.hash(id, username, displayName, avatarUrl, isOnline, lastSeen);
}
