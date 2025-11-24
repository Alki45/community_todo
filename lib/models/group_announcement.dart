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
    this.attachments = const [],
  });

  final String id;
  final String groupId;
  final String authorUid;
  final String authorName;
  final String message;
  final DateTime createdAt;
  final bool isHadith;
  final bool pinned;
  final List<FileAttachment> attachments;

  factory GroupAnnouncement.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final attachmentsData = data['attachments'] as List<dynamic>? ?? [];
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
      attachments: attachmentsData
          .map((item) => FileAttachment.fromMap(item as Map<String, dynamic>))
          .toList(),
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
      'attachments': attachments.map((a) => a.toMap()).toList(),
    };
  }
}

class FileAttachment {
  const FileAttachment({
    required this.url,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
  });

  final String url;
  final String fileName;
  final String fileType; // 'image', 'pdf', 'word', etc.
  final int fileSize; // in bytes

  factory FileAttachment.fromMap(Map<String, dynamic> map) {
    return FileAttachment(
      url: map['url'] as String? ?? '',
      fileName: map['file_name'] as String? ?? '',
      fileType: map['file_type'] as String? ?? '',
      fileSize: map['file_size'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize,
    };
  }
  
  bool get isImage => fileType == 'image';
  bool get isPdf => fileType == 'pdf';
  bool get isWord => fileType == 'word';
}
