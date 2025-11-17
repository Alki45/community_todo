import 'package:cloud_firestore/cloud_firestore.dart';

class GroupAnnouncement {
  const GroupAnnouncement({
    required this.id,
    required this.groupId,
    required this.authorUid,
    required this.authorName,
    required this.message,
    required this.createdAt,
    this.isHadith = false,
    this.pinned = false,
  });

  final String id;
  final String groupId;
  final String authorUid;
  final String authorName;
  final String message;
  final DateTime createdAt;
  final bool isHadith;
  final bool pinned;

  factory GroupAnnouncement.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return GroupAnnouncement(
      id: doc.id,
      groupId: data['group_id'] as String? ?? '',
      authorUid: data['author_uid'] as String? ?? '',
      authorName: data['author_name'] as String? ?? '',
      message: data['message'] as String? ?? '',
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isHadith: data['is_hadith'] as bool? ?? false,
      pinned: data['pinned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'author_uid': authorUid,
      'author_name': authorName,
      'message': message,
      'created_at': Timestamp.fromDate(createdAt),
      'is_hadith': isHadith,
      'pinned': pinned,
    };
  }
}
