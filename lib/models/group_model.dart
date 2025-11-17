import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  const Group({
    required this.id,
    required this.name,
    required this.adminUid,
    required this.members,
    required this.memberIds,
    required this.inviteCode,
    required this.createdAt,
    required this.isPublic,
    this.description,
    this.shareableLink,
    this.requiresApproval = false,
    this.adminVotes = const {},
  });

  final String id;
  final String name;
  final String adminUid;
  final List<GroupMember> members;
  final List<String> memberIds;
  final String inviteCode;
  final String? shareableLink;
  final DateTime createdAt;
  final bool isPublic;
  final String? description;
  final bool requiresApproval;
  final Map<String, List<String>> adminVotes;

  bool get hasDescription => (description ?? '').trim().isNotEmpty;
  int get memberCount => members.length;

  Group copyWith({
    String? name,
    String? adminUid,
    List<GroupMember>? members,
    List<String>? memberIds,
    String? inviteCode,
    String? shareableLink,
    DateTime? createdAt,
    bool? isPublic,
    String? description,
    bool? requiresApproval,
    Map<String, List<String>>? adminVotes,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      adminUid: adminUid ?? this.adminUid,
      members: members ?? this.members,
      memberIds: memberIds ?? this.memberIds,
      inviteCode: inviteCode ?? this.inviteCode,
      shareableLink: shareableLink ?? this.shareableLink,
      createdAt: createdAt ?? this.createdAt,
      isPublic: isPublic ?? this.isPublic,
      description: description ?? this.description,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      adminVotes: adminVotes ?? this.adminVotes,
    );
  }

  factory Group.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final membersData = (data['members'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    return Group(
      id: doc.id,
      name: data['name'] as String? ?? '',
      adminUid: data['admin_uid'] as String? ?? '',
      members: membersData
          .map((item) => GroupMember.fromMap(item))
          .toList(growable: false),
      memberIds: (data['member_ids'] as List<dynamic>? ?? []).cast<String>(),
      inviteCode: data['invite_code'] as String? ?? '',
      shareableLink: data['shareable_link'] as String?,
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isPublic: data['is_public'] as bool? ?? false,
      description: data['description'] as String?,
      requiresApproval: data['requires_approval'] as bool? ?? false,
      adminVotes: (data['admin_votes'] as Map<String, dynamic>? ?? {}).map(
        (key, value) => MapEntry(key, (value as List<dynamic>).cast<String>()),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'admin_uid': adminUid,
      'members': members.map((member) => member.toMap()).toList(),
      'member_ids': memberIds,
      'invite_code': inviteCode,
      if (shareableLink != null) 'shareable_link': shareableLink,
      'created_at': Timestamp.fromDate(createdAt),
      'is_public': isPublic,
      'requires_approval': requiresApproval,
      if (description != null) 'description': description,
      'admin_votes': adminVotes,
    };
  }
}

class GroupMember {
  const GroupMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.joinedAt,
    this.status = 'active',
    this.lastActiveAt,
  });

  final String uid;
  final String name;
  final String email;
  final DateTime joinedAt;
  final String status; // 'active', 'away', 'busy', 'offline'
  final DateTime? lastActiveAt;

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      uid: map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      joinedAt:
          (map['joined_at'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: map['status'] as String? ?? 'active',
      lastActiveAt: (map['last_active_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'joined_at': Timestamp.fromDate(joinedAt),
      'status': status,
      if (lastActiveAt != null)
        'last_active_at': Timestamp.fromDate(lastActiveAt!),
    };
  }

  GroupMember copyWith({
    String? uid,
    String? name,
    String? email,
    DateTime? joinedAt,
    String? status,
    DateTime? lastActiveAt,
  }) {
    return GroupMember(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      joinedAt: joinedAt ?? this.joinedAt,
      status: status ?? this.status,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }
}
