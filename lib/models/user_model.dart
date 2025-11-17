import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.groups,
    this.photoUrl,
    this.createdAt,
    this.deviceTokens = const [],
    this.searchTokens = const [],
    this.activeGroupId,
    this.username,
    this.country,
    this.city,
    this.bio,
  });

  final String uid;
  final String name;
  final String email;
  final List<String> groups;
  final String? photoUrl;
  final DateTime? createdAt;
  final List<String> deviceTokens;
  final List<String> searchTokens;
  final String? activeGroupId;
  final String? username;
  final String? country;
  final String? city;
  final String? bio;

  bool get hasCompletedProfile =>
      name.trim().isNotEmpty && (username?.trim().isNotEmpty ?? false);

  AppUser copyWith({
    String? name,
    String? email,
    List<String>? groups,
    String? photoUrl,
    DateTime? createdAt,
    List<String>? deviceTokens,
    List<String>? searchTokens,
    String? activeGroupId,
    String? username,
    String? country,
    String? city,
    String? bio,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      groups: groups ?? this.groups,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      deviceTokens: deviceTokens ?? this.deviceTokens,
      searchTokens: searchTokens ?? this.searchTokens,
      activeGroupId: activeGroupId ?? this.activeGroupId,
      username: username ?? this.username,
      country: country ?? this.country,
      city: city ?? this.city,
      bio: bio ?? this.bio,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'groups': groups,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      'deviceTokens': deviceTokens,
      'searchTokens': searchTokens,
      if (activeGroupId != null) 'activeGroupId': activeGroupId,
      if (username != null) 'username': username,
      if (country != null) 'country': country,
      if (city != null) 'city': city,
      if (bio != null) 'bio': bio,
    };
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    final createdAt = map['created_at'];
    return AppUser(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      groups: (map['groups'] as List<dynamic>? ?? []).cast<String>(),
      photoUrl: map['photoUrl'] as String?,
      createdAt: createdAt is Timestamp ? createdAt.toDate() : null,
      deviceTokens: (map['deviceTokens'] as List<dynamic>? ?? [])
          .cast<String>(),
      searchTokens: (map['searchTokens'] as List<dynamic>? ?? [])
          .cast<String>(),
      activeGroupId: map['activeGroupId'] as String?,
      username: map['username'] as String?,
      country: map['country'] as String?,
      city: map['city'] as String?,
      bio: map['bio'] as String?,
    );
  }
}
