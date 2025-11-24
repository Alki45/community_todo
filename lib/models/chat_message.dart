import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_announcement.dart'; // Reuse FileAttachment

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.groupId,
    required this.senderUid,
    required this.senderName,
    required this.message,
    required this.createdAt,
    this.attachments = const [],
  });

  final String id;
  final String groupId;
  final String senderUid;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final List<FileAttachment> attachments;

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final attachmentsData = data['attachments'] as List<dynamic>? ?? [];
    return ChatMessage(
      id: doc.id,
      groupId: data['group_id'] as String? ?? '',
      senderUid: data['sender_uid'] as String? ?? '',
      senderName: data['sender_name'] as String? ?? '',
      message: data['message'] as String? ?? '',
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      attachments: attachmentsData
          .map((item) => FileAttachment.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'sender_uid': senderUid,
      'sender_name': senderName,
      'message': message,
      'created_at': Timestamp.fromDate(createdAt),
      'attachments': attachments.map((a) => a.toMap()).toList(),
    };
  }
}




