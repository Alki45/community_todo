import 'package:cloud_firestore/cloud_firestore.dart';

class RecitationAssignment {
  const RecitationAssignment({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.assignedBy,
    required this.assignedByName,
    required this.assignedTo,
    required this.assignedToName,
    required this.juzNumber,
    required this.surah,
    required this.ayatRange,
    required this.status,
    required this.assignedDate,
    this.deadline,
    this.completedDate,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String assignedBy;
  final String assignedByName;
  final String assignedTo;
  final String assignedToName;
  final double juzNumber;
  final String? surah;
  final String? ayatRange;
  final String status;
  final DateTime assignedDate;
  final DateTime? deadline;
  final DateTime? completedDate;

  bool get isCompleted => status == 'completed';
  bool get isPastDue =>
      deadline != null &&
      !isCompleted &&
      DateTime.now().isAfter(deadline!.add(const Duration(days: 1)));

  RecitationAssignment copyWith({String? status, DateTime? completedDate}) {
    return RecitationAssignment(
      id: id,
      groupId: groupId,
      groupName: groupName,
      assignedBy: assignedBy,
      assignedByName: assignedByName,
      assignedTo: assignedTo,
      assignedToName: assignedToName,
      juzNumber: juzNumber,
      surah: surah,
      ayatRange: ayatRange,
      status: status ?? this.status,
      assignedDate: assignedDate,
      deadline: deadline,
      completedDate: completedDate ?? this.completedDate,
    );
  }

  factory RecitationAssignment.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return RecitationAssignment(
      id: doc.id,
      groupId: data['group_id'] as String? ?? '',
      groupName: data['group_name'] as String? ?? '',
      assignedBy: data['assigned_by'] as String? ?? '',
      assignedByName: data['assigned_by_name'] as String? ?? '',
      assignedTo: data['assigned_to'] as String? ?? '',
      assignedToName: data['assigned_to_name'] as String? ?? '',
      juzNumber: (data['juz_number'] as num?)?.toDouble() ?? 1.0,
      surah: data['surah'] as String?,
      ayatRange: data['ayat_range'] as String?,
      status: data['status'] as String? ?? 'pending',
      assignedDate:
          (data['assigned_date'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
      completedDate: (data['completed_date'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'group_name': groupName,
      'assigned_by': assignedBy,
      'assigned_by_name': assignedByName,
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'juz_number': juzNumber,
      if (surah != null && surah!.isNotEmpty) 'surah': surah,
      if (ayatRange != null && ayatRange!.isNotEmpty) 'ayat_range': ayatRange,
      'status': status,
      'assigned_date': Timestamp.fromDate(assignedDate),
      if (deadline != null) 'deadline': Timestamp.fromDate(deadline!),
      if (completedDate != null)
        'completed_date': Timestamp.fromDate(completedDate!),
    };
  }
}
