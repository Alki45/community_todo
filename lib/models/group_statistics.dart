class GroupStatistics {
  const GroupStatistics({
    required this.groupId,
    required this.totalAssignments,
    required this.completedAssignments,
    required this.pendingAssignments,
    required this.membersProgress,
    this.juzCompleted = 0,
    this.juzProgress = 0.0,
  });

  final String groupId;
  final int totalAssignments;
  final int completedAssignments;
  final int pendingAssignments;
  final List<MemberProgress> membersProgress;
  final int juzCompleted; // Unique juz completed (out of 30)
  final double juzProgress; // Progress as fraction of 30 juz (0.0 to 1.0)

  double get completionRate =>
      totalAssignments == 0 ? 0 : completedAssignments / totalAssignments;
}

class MemberProgress {
  const MemberProgress({
    required this.uid,
    required this.name,
    required this.completed,
    required this.pending,
    this.juzCompleted = 0,
    this.juzTotal = 0,
    this.juzProgress = 0.0,
  });

  final String uid;
  final String name;
  final int completed;
  final int pending;
  final int juzCompleted; // Unique juz completed
  final int juzTotal; // Unique juz assigned
  final double juzProgress; // Progress as fraction of 30 juz (0.0 to 1.0)

  int get total => completed + pending;

  double get completionRate => total == 0 ? 0 : completed / total;
}
