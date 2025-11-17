import 'package:cloud_firestore/cloud_firestore.dart';

class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.groupId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.requestedAt,
    this.status = 'pending', // 'pending', 'approved', 'rejected'
    this.reviewedBy,
    this.reviewedAt,
    this.message,
  });

  final String id;
  final String groupId;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime requestedAt;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? message;

  factory JoinRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return JoinRequest(
      id: doc.id,
      groupId: data['group_id'] as String? ?? '',
      userId: data['user_id'] as String? ?? '',
      userName: data['user_name'] as String? ?? '',
      userEmail: data['user_email'] as String? ?? '',
      requestedAt:
          (data['requested_at'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: data['status'] as String? ?? 'pending',
      reviewedBy: data['reviewed_by'] as String?,
      reviewedAt: (data['reviewed_at'] as Timestamp?)?.toDate(),
      message: data['message'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'requested_at': Timestamp.fromDate(requestedAt),
      'status': status,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      if (reviewedAt != null) 'reviewed_at': Timestamp.fromDate(reviewedAt!),
      if (message != null) 'message': message,
    };
  }
}







