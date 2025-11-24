import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/group_model.dart';
import '../models/recitation_model.dart';

/// Service for managing weekly Juz assignments
class WeeklyAssignmentService {
  WeeklyAssignmentService(this._firestore);

  final FirebaseFirestore _firestore;
  final CollectionReference<Map<String, dynamic>> _recitationsRef =
      FirebaseFirestore.instance.collection('recitations');
  final CollectionReference<Map<String, dynamic>> _groupsRef =
      FirebaseFirestore.instance.collection('groups');

  /// Generate a week ID based on sequential week number
  /// Format: groupId-weekN (e.g., group123-week1, group123-week2)
  String _generateWeekId(String groupId, int weekNumber) {
    return '$groupId-week$weekNumber';
  }
  
  /// Get the next sequential week number for a group
  Future<int> _getNextWeekNumber(String groupId) async {
    final groupDoc = await _groupsRef.doc(groupId).get();
    if (!groupDoc.exists) {
      return 1; // First week
    }
    final data = groupDoc.data();
    final currentWeekNumber = data?['week_number'] as int?;
    return (currentWeekNumber ?? 0) + 1;
  }

  /// Get ISO week number (ISO 8601)
  int _getWeekNumber(DateTime date) {
    // ISO 8601 week number calculation
    final d = DateTime.utc(date.year, date.month, date.day);
    final dayNum = d.weekday == 7 ? 0 : d.weekday; // Convert Sunday=7 to 0
    final adjustedDate = d.subtract(Duration(days: dayNum - 1)); // Move to Monday of the week
    final week1 = DateTime.utc(adjustedDate.year, 1, 4); // Week 1 contains Jan 4
    final week1Monday = week1.subtract(Duration(days: week1.weekday - 1));
    final weekNumber = ((adjustedDate.difference(week1Monday).inDays) / 7).floor() + 1;
    return weekNumber;
  }

  /// Get the start of the current week (Monday)
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday; // 1 = Monday, 7 = Sunday
    return date.subtract(Duration(days: weekday - 1));
  }

  /// Get the end of the current week (Sunday)
  DateTime _getWeekEnd(DateTime weekStart) {
    return weekStart.add(const Duration(days: 6));
  }

  /// Get current week ID for a group
  Future<String> getCurrentWeekId(String groupId) async {
    final groupDoc = await _groupsRef.doc(groupId).get();
    if (!groupDoc.exists) {
      return _generateWeekId(groupId, 1);
    }
    final data = groupDoc.data();
    final currentWeekId = data?['current_week_id'] as String?;
    if (currentWeekId != null) {
      return currentWeekId;
    }
    // If no current week, return week 1
    return _generateWeekId(groupId, 1);
  }

  /// Assign all 30 Juz to group members for the current week
  Future<void> assignWeeklyJuz({
    required Group group,
    required GroupMember assignedBy,
    DateTime? weekStart,
    int? weekNumber,
  }) async {
    if (group.members.isEmpty) {
      throw StateError('Group has no members');
    }

    final now = DateTime.now();
    final startDate = weekStart ?? _getWeekStart(now);
    final endDate = _getWeekEnd(startDate);
    
    // Get or determine week number
    final nextWeekNumber = weekNumber ?? await _getNextWeekNumber(group.id);
    final weekId = _generateWeekId(group.id, nextWeekNumber);

    // Check if assignments already exist for this week
    final existingAssignments = await _recitationsRef
        .where('group_id', isEqualTo: group.id)
        .where('week_id', isEqualTo: weekId)
        .get();

    if (existingAssignments.docs.isNotEmpty) {
      throw StateError('Weekly assignments already exist for this week');
    }

    // Distribute 30 Juz among members
    final members = group.members;
    final juzList = List.generate(30, (index) => index + 1);
    final assignmentsPerMember = (30 / members.length).ceil();
    final assignments = <RecitationAssignment>[];

    int juzIndex = 0;
    for (int memberIndex = 0; memberIndex < members.length; memberIndex++) {
      final member = members[memberIndex];
      final juzForMember = <int>[];

      // Distribute juz evenly
      for (int i = 0; i < assignmentsPerMember && juzIndex < juzList.length; i++) {
        // If this is the last member and there are remaining juz, give them all
        if (memberIndex == members.length - 1) {
          // Last member gets all remaining juz
          while (juzIndex < juzList.length) {
            juzForMember.add(juzList[juzIndex]);
            juzIndex++;
          }
        } else {
          juzForMember.add(juzList[juzIndex]);
          juzIndex++;
        }
      }

      // Create assignments for this member
      for (final juzNumber in juzForMember) {
        final assignment = RecitationAssignment(
          id: '', // Will be set by Firestore
          groupId: group.id,
          groupName: group.name,
          assignedBy: assignedBy.uid,
          assignedByName: assignedBy.name,
          assignedTo: member.uid,
          assignedToName: member.name,
          juzNumber: juzNumber.toDouble(),
          surah: null,
          ayatRange: null,
          status: 'pending',
          assignedDate: now,
          deadline: endDate,
          weekId: weekId,
          weekStartDate: startDate,
          weekEndDate: endDate,
        );
        assignments.add(assignment);
      }
    }

    // Batch write all assignments
    final batch = _firestore.batch();
    for (final assignment in assignments) {
      final docRef = _recitationsRef.doc();
      batch.set(docRef, assignment.toMap());
    }
    await batch.commit();

    // Update group's current_week_id and week_number
    await _groupsRef.doc(group.id).update({
      'current_week_id': weekId,
      'week_number': nextWeekNumber,
      'last_week_reset': FieldValue.serverTimestamp(),
    });
  }
  
  /// Check if a week is complete and auto-create next week if needed
  Future<bool> checkAndCreateNextWeek({
    required String groupId,
    required String completedWeekId,
  }) async {
    // Check if week is complete
    final isComplete = await isWeekComplete(
      groupId: groupId,
      weekId: completedWeekId,
    );
    
    if (!isComplete) {
      return false;
    }
    
    // Get group data
    final groupDoc = await _groupsRef.doc(groupId).get();
    if (!groupDoc.exists) {
      return false;
    }
    
    final groupData = groupDoc.data()!;
    final membersData = (groupData['members'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    
    if (membersData.isEmpty) {
      return false;
    }
    
    // Check if next week already exists
    final currentWeekNumber = groupData['week_number'] as int? ?? 0;
    final nextWeekNumber = currentWeekNumber + 1;
    final nextWeekId = _generateWeekId(groupId, nextWeekNumber);
    
    final existingNextWeek = await _recitationsRef
        .where('group_id', isEqualTo: groupId)
        .where('week_id', isEqualTo: nextWeekId)
        .limit(1)
        .get();
    
    if (existingNextWeek.docs.isNotEmpty) {
      return false; // Next week already exists
    }
    
    // Find admin member
    final adminUid = groupData['admin_uid'] as String?;
    if (adminUid == null) {
      return false;
    }
    
    final adminMemberData = membersData.firstWhere(
      (m) => m['uid'] == adminUid,
      orElse: () => membersData.first,
    );
    
    final adminMember = GroupMember.fromMap(adminMemberData);
    
    // Create group object for assignment
    final group = Group.fromDoc(groupDoc);
    
    // Auto-create next week
    final now = DateTime.now();
    final nextWeekStart = _getWeekStart(now);
    
    await assignWeeklyJuz(
      group: group,
      assignedBy: adminMember,
      weekStart: nextWeekStart,
      weekNumber: nextWeekNumber,
    );
    
    return true;
  }

  /// Get assignments for a specific week
  Future<List<RecitationAssignment>> getWeekAssignments({
    required String groupId,
    required String weekId,
  }) async {
    final snapshot = await _recitationsRef
        .where('group_id', isEqualTo: groupId)
        .where('week_id', isEqualTo: weekId)
        .get();

    return snapshot.docs
        .map((doc) => RecitationAssignment.fromDoc(doc))
        .toList();
  }

  /// Extract week number from weekId (e.g., "groupId-week1" -> 1)
  int? getWeekNumberFromId(String weekId) {
    final parts = weekId.split('-week');
    if (parts.length == 2) {
      return int.tryParse(parts[1]);
    }
    return null;
  }
  
  /// Get all past weeks for a group
  Future<List<String>> getPastWeekIds(String groupId) async {
    final snapshot = await _recitationsRef
        .where('group_id', isEqualTo: groupId)
        .where('week_id', isNotEqualTo: null)
        .get();

    final weekIds = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final weekId = data['week_id'] as String?;
      if (weekId != null) {
        weekIds.add(weekId);
      }
    }

    // Sort week IDs descending (most recent first)
    final sorted = weekIds.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Check if all 30 Juz are completed for a week
  Future<bool> isWeekComplete({
    required String groupId,
    required String weekId,
  }) async {
    final assignments = await getWeekAssignments(
      groupId: groupId,
      weekId: weekId,
    );

    if (assignments.isEmpty) {
      return false;
    }

    final completedJuz = <int>{};
    for (final assignment in assignments) {
      if (assignment.isCompleted) {
        completedJuz.add(assignment.juzNumber.toInt());
      }
    }

    return completedJuz.length == 30;
  }

  /// Get completion statistics for a week
  Future<Map<String, dynamic>> getWeekStatistics({
    required String groupId,
    required String weekId,
  }) async {
    final assignments = await getWeekAssignments(
      groupId: groupId,
      weekId: weekId,
    );

    final completedJuz = <int>{};
    final totalAssignments = assignments.length;
    int completedAssignments = 0;

    for (final assignment in assignments) {
      if (assignment.isCompleted) {
        completedAssignments++;
        completedJuz.add(assignment.juzNumber.toInt());
      }
    }

    return {
      'total_assignments': totalAssignments,
      'completed_assignments': completedAssignments,
      'unique_juz_completed': completedJuz.length,
      'is_complete': completedJuz.length == 30,
      'completion_rate': totalAssignments > 0
          ? completedAssignments / totalAssignments
          : 0.0,
    };
  }
  
  /// Get member-level completion statistics for a week
  /// Returns counts of how many members completed, in progress, or not started
  Future<Map<String, int>> getMemberCompletionStats({
    required String groupId,
    required String weekId,
  }) async {
    final assignments = await getWeekAssignments(
      groupId: groupId,
      weekId: weekId,
    );
    
    // Group assignments by member
    final memberAssignments = <String, List<RecitationAssignment>>{};
    for (final assignment in assignments) {
      if (!memberAssignments.containsKey(assignment.assignedTo)) {
        memberAssignments[assignment.assignedTo] = [];
      }
      memberAssignments[assignment.assignedTo]!.add(assignment);
    }
    
    int completedMembers = 0;
    int inProgressMembers = 0;
    int notStartedMembers = 0;
    
    for (final memberAssigns in memberAssignments.values) {
      final completedCount = memberAssigns.where((a) => a.isCompleted).length;
      final inProgressCount = memberAssigns.where((a) => a.status == 'ongoing').length;
      final totalCount = memberAssigns.length;
      
      if (completedCount == totalCount) {
        completedMembers++;
      } else if (inProgressCount > 0 || completedCount > 0) {
        inProgressMembers++;
      } else {
        notStartedMembers++;
      }
    }
    
    return {
      'completed_members': completedMembers,
      'in_progress_members': inProgressMembers,
      'not_started_members': notStartedMembers,
      'total_members': memberAssignments.length,
    };
  }
}

