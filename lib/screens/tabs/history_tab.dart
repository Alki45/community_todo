import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/group_model.dart';
import '../../models/recitation_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/weekly_assignment_service.dart';
import '../../widgets/celebration_widget.dart';
import '../../widgets/todo_item.dart';
import '../../widgets/refresh_button.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String? _selectedGroupId;
  String? _selectedWeekId; // For filtering statistics by week
  bool _showStatistics = false; // Track if statistics card is expanded
  final Map<String, List<RecitationAssignment>> _weekAssignments = {};
  final Map<String, Map<String, dynamic>> _weekStats = {};
  
  /// Find the most recent completed week
  Future<String?> _findLastCompletedWeek(
    WeeklyAssignmentService weeklyService,
    String groupId,
    List<String> sortedWeekIds,
  ) async {
    for (final weekId in sortedWeekIds) {
      final isComplete = await weeklyService.isWeekComplete(
        groupId: groupId,
        weekId: weekId,
      );
      if (isComplete) {
        return weekId;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    final firestore = context.read<FirestoreService>();
    final weeklyService = WeeklyAssignmentService(FirebaseFirestore.instance);

    if (userProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (user == null) {
      return const Center(
        child: Text('Sign in to view your recitation history.'),
      );
    }

    return StreamBuilder<List<Group>>(
      stream: firestore.watchUserGroups(user.uid),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (groups.isEmpty) {
          return const Center(
            child: Text('No groups yet. Join a group to see history.'),
          );
        }

        // Auto-select group
        if (_selectedGroupId == null ||
            !groups.any((g) => g.id == _selectedGroupId)) {
          final providerActive = userProvider.activeGroupId;
          if (providerActive != null &&
              groups.any((g) => g.id == providerActive)) {
            _selectedGroupId = providerActive;
          } else {
            _selectedGroupId = groups.first.id;
          }
        }

        final selectedGroup = groups.firstWhere(
          (g) => g.id == _selectedGroupId,
          orElse: () => groups.first,
        );

        final isSmallScreen = MediaQuery.of(context).size.height < 700;
        return ListView(
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? 24 : 16,
            vertical: isSmallScreen ? 16 : 24,
          ),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Recitation History & Statistics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 18 : null,
                          ),
                          ),
                        ),
                        RefreshButton(
                          onRefresh: () async {
                            await userProvider.refreshUser();
                            setState(() {
                              _weekAssignments.clear();
                              _weekStats.clear();
                            });
                          },
                          tooltip: 'Refresh history',
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Select group',
                        prefixIcon: Icon(Icons.groups),
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGroupId,
                          isExpanded: true,
                          items: groups
                              .map(
                                (group) => DropdownMenuItem(
                                  value: group.id,
                                  child: Text(
                                    group.name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedGroupId = value;
                                _selectedWeekId = null;
                                _weekAssignments.clear();
                                _weekStats.clear();
                              });
                              userProvider.setActiveGroup(value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Statistics toggle button - only show if a week is selected
            if (_selectedWeekId != null) ...[
              SizedBox(height: isSmallScreen ? 12 : 16),
              Card(
                elevation: 0,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showStatistics = !_showStatistics;
                    });
                  },
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bar_chart,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'View Statistics',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isSmallScreen ? 16 : null,
                                ),
                          ),
                        ),
                        Icon(
                          _showStatistics ? Icons.expand_less : Icons.expand_more,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Show statistics card when expanded
              if (_showStatistics) ...[
                SizedBox(height: isSmallScreen ? 8 : 12),
                _WeekStatisticsCard(
                  groupId: selectedGroup.id,
                  weekId: _selectedWeekId!,
                  weeklyService: weeklyService,
                  isAdmin: selectedGroup.adminUid == user.uid,
                ),
              ],
            ],
            SizedBox(height: isSmallScreen ? 12 : 16),
            FutureBuilder<List<String>>(
              future: weeklyService.getPastWeekIds(selectedGroup.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final weekIds = snapshot.data ?? [];

                if (weekIds.isEmpty) {
                  return Card(
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_outlined,
                            size: isSmallScreen ? 48 : 64,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          Text(
                            'No history yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: isSmallScreen ? 16 : null,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6 : 8),
                          Text(
                            'Weekly assignments will appear here once they are created.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: isSmallScreen ? 13 : null,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Sort weeks by week number (descending - most recent first)
                final sortedWeekIds = weekIds.toList()
                  ..sort((a, b) {
                    final weekNumA = weeklyService.getWeekNumberFromId(a) ?? 0;
                    final weekNumB = weeklyService.getWeekNumberFromId(b) ?? 0;
                    return weekNumB.compareTo(weekNumA);
                  });
                
                return FutureBuilder<String?>(
                  future: _findLastCompletedWeek(
                    weeklyService,
                    selectedGroup.id,
                    sortedWeekIds,
                  ),
                  builder: (context, lastCompletedSnapshot) {
                    final lastCompletedWeekId = lastCompletedSnapshot.data;

                return Column(
                      children: [
                        // Week Filter Dropdown
                        if (sortedWeekIds.isNotEmpty) ...[
                          Card(
                            elevation: 0,
                            child: Padding(
                              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Filter by week (optional)',
                                  prefixIcon: Icon(Icons.filter_list),
                                  border: OutlineInputBorder(),
                                  helperText: 'Select a week to view detailed statistics',
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: _selectedWeekId,
                                    isExpanded: true,
                                    hint: const Text('All weeks'),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('All weeks'),
                                      ),
                                      ...sortedWeekIds.map(
                                        (weekId) {
                                          final weekNum = weeklyService.getWeekNumberFromId(weekId);
                                          return DropdownMenuItem<String?>(
                                            value: weekId,
                                            child: Text(
                                              weekNum != null ? 'Week $weekNum' : weekId,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedWeekId = value;
                                        _showStatistics = false; // Reset statistics visibility when week changes
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                        ],
                        // Filter weeks if a specific week is selected
                        ...(_selectedWeekId != null
                            ? sortedWeekIds.where((id) => id == _selectedWeekId).toList()
                            : sortedWeekIds).map((weekId) {
                    return _WeekHistoryCard(
                      groupId: selectedGroup.id,
                      weekId: weekId,
                      weeklyService: weeklyService,
                            isAdmin: selectedGroup.adminUid == user.uid,
                            isLastCompleted: weekId == lastCompletedWeekId,
                    );
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _WeekHistoryCard extends StatefulWidget {
  const _WeekHistoryCard({
    required this.groupId,
    required this.weekId,
    required this.weeklyService,
    required this.isAdmin,
    this.isLastCompleted = false,
  });

  final String groupId;
  final String weekId;
  final WeeklyAssignmentService weeklyService;
  final bool isAdmin;
  final bool isLastCompleted;

  @override
  State<_WeekHistoryCard> createState() => _WeekHistoryCardState();
}

class _WeekHistoryCardState extends State<_WeekHistoryCard> {
  List<RecitationAssignment>? _assignments;
  Map<String, dynamic>? _stats;
  Map<String, int>? _memberStats; // For member view: completion counts
  bool _isExpanded = false;
  bool _showCelebration = false;

  @override
  void initState() {
    super.initState();
    _loadWeekData();
  }

  Future<void> _loadWeekData() async {
    final assignments = await widget.weeklyService.getWeekAssignments(
      groupId: widget.groupId,
      weekId: widget.weekId,
    );
    final stats = await widget.weeklyService.getWeekStatistics(
      groupId: widget.groupId,
      weekId: widget.weekId,
    );
    
    // Load member completion stats for non-admin members
    Map<String, int>? memberStats;
    if (!widget.isAdmin) {
      memberStats = await widget.weeklyService.getMemberCompletionStats(
        groupId: widget.groupId,
        weekId: widget.weekId,
      );
    }

    if (mounted) {
      setState(() {
        _assignments = assignments;
        _stats = stats;
        _memberStats = memberStats;
        // Show celebration if all 30 Juz are completed
        if (stats['is_complete'] == true && !_showCelebration) {
          _showCelebration = true;
          // Auto-hide celebration after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _showCelebration = false;
              });
            }
          });
        }
      });
    }
  }

  String _formatWeekId(String weekId) {
    // Format: groupId-week1 -> "Week 1"
    final weekNumber = widget.weeklyService.getWeekNumberFromId(weekId);
    if (weekNumber != null) {
      if (widget.isLastCompleted && _stats != null && _stats!['is_complete'] == true) {
        return 'Week $weekNumber - Last week completed ✓';
      }
      return 'Week $weekNumber';
    }
    return weekId;
  }

  DateTime? _getWeekStartDate() {
    if (_assignments == null || _assignments!.isEmpty) {
      return null;
    }
    return _assignments!.first.weekStartDate;
  }
  
  /// Group assignments by member for admin view
  Map<String, List<RecitationAssignment>> _getMemberAssignments() {
    if (_assignments == null) {
      return {};
    }
    
    final grouped = <String, List<RecitationAssignment>>{};
    for (final assignment in _assignments!) {
      final memberName = assignment.assignedToName;
      if (!grouped.containsKey(memberName)) {
        grouped[memberName] = [];
      }
      grouped[memberName]!.add(assignment);
    }
    
    // Sort by completion status (completed members first)
    final sorted = grouped.entries.toList()
      ..sort((a, b) {
        final aComplete = a.value.every((as) => as.isCompleted);
        final bComplete = b.value.every((as) => as.isCompleted);
        if (aComplete && !bComplete) return -1;
        if (!aComplete && bComplete) return 1;
        return a.key.compareTo(b.key);
      });
    
    return Map.fromEntries(sorted);
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    if (_assignments == null || _stats == null) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final weekStart = _getWeekStartDate();
    final weekEnd = _assignments!.first.weekEndDate;
    final isComplete = _stats!['is_complete'] == true;
    final uniqueJuzCompleted = _stats!['unique_juz_completed'] as int;
    final completionRate = _stats!['completion_rate'] as double;

    return Stack(
      children: [
        Card(
          elevation: 0,
          color: isComplete
              ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
              : null,
          child: InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatWeekId(widget.weekId),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 16 : null,
                                  ),
                            ),
                            if (weekStart != null && weekEnd != null) ...[
                              SizedBox(height: isSmallScreen ? 2 : 4),
                              Text(
                                '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d, y').format(weekEnd)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: isSmallScreen ? 10 : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isComplete)
                        Icon(
                          Icons.celebration,
                          color: Theme.of(context).colorScheme.primary,
                          size: isSmallScreen ? 20 : 24,
                        )
                      else
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: isSmallScreen ? 20 : 24,
                        ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  LinearProgressIndicator(
                    value: completionRate,
                    minHeight: isSmallScreen ? 6 : 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  if (widget.isAdmin) ...[
                    // Admin view: Show Juz and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatChip(
                        label: 'Juz Completed',
                        value: '$uniqueJuzCompleted/30',
                        color: Theme.of(context).colorScheme.secondaryContainer,
                      ),
                      _StatChip(
                        label: 'Status',
                        value: isComplete ? 'Complete' : 'In Progress',
                        color: isComplete
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.tertiaryContainer,
                      ),
                    ],
                  ),
                  ] else ...[
                    // Member view: Show group progress statistics
                    if (_memberStats != null) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceEvenly,
                        children: [
                          _StatChip(
                            label: 'Completed',
                            value: '${_memberStats!['completed_members']} ${_memberStats!['completed_members'] == 1 ? 'person' : 'people'}',
                            color: Theme.of(context).colorScheme.secondaryContainer,
                          ),
                          _StatChip(
                            label: 'In Progress',
                            value: '${_memberStats!['in_progress_members']} ${_memberStats!['in_progress_members'] == 1 ? 'person' : 'people'}',
                            color: Theme.of(context).colorScheme.tertiaryContainer,
                          ),
                          _StatChip(
                            label: 'Not Started',
                            value: '${_memberStats!['not_started_members']} ${_memberStats!['not_started_members'] == 1 ? 'person' : 'people'}',
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                        ],
                      ),
                    ] else ...[
                      // Fallback if stats not loaded
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatChip(
                            label: 'Juz Completed',
                            value: '$uniqueJuzCompleted/30',
                            color: Theme.of(context).colorScheme.secondaryContainer,
                          ),
                          _StatChip(
                            label: 'Status',
                            value: isComplete ? 'Complete' : 'In Progress',
                            color: isComplete
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context).colorScheme.tertiaryContainer,
                          ),
                        ],
                      ),
                    ],
                  ],
                  if (_isExpanded) ...[
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    const Divider(),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    if (isComplete)
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.celebration,
                              size: isSmallScreen ? 20 : 24,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 12),
                            Expanded(
                              child: Text(
                                'Your team has successfully completed the Quran. Make duas.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: isSmallScreen ? 13 : null,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Text(
                      widget.isAdmin ? 'Member Assignments' : 'My Progress',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontSize: isSmallScreen ? 13 : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    if (widget.isAdmin) ...[
                      // Group assignments by member for admin view
                      ..._getMemberAssignments().entries.map((entry) {
                        final memberName = entry.key;
                        final memberAssignments = entry.value;
                        final completedCount = memberAssignments.where((a) => a.isCompleted).length;
                        final totalCount = memberAssignments.length;
                        final isMemberComplete = completedCount == totalCount;
                        
                        return Card(
                          elevation: 0,
                          color: isMemberComplete
                              ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                          child: Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isMemberComplete
                                          ? Icons.check_circle
                                          : Icons.person_outline,
                                      size: isSmallScreen ? 18 : 20,
                                      color: isMemberComplete
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    SizedBox(width: isSmallScreen ? 8 : 12),
                                    Expanded(
                                      child: Text(
                                        memberName,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontSize: isSmallScreen ? 14 : null,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      label: Text('$completedCount/$totalCount'),
                                      backgroundColor: isMemberComplete
                                          ? Theme.of(context).colorScheme.primaryContainer
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 6 : 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: memberAssignments.map((assignment) {
                                    return Chip(
                                      avatar: Icon(
                                        assignment.isCompleted
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        size: 16,
                                        color: assignment.isCompleted
                                            ? Theme.of(context).colorScheme.primary
                                            : Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                      label: Text('Juz ${assignment.juzNumber.toInt()}'),
                                      backgroundColor: assignment.isCompleted
                                          ? Theme.of(context).colorScheme.secondaryContainer
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ] else ...[
                      // Regular member view - show only their assignments with status
                      Builder(
                        builder: (context) {
                          final user = context.read<UserProvider>().user;
                          if (user == null) {
                            return const SizedBox.shrink();
                          }
                          
                          final myAssignments = _assignments!
                              .where((a) => a.assignedTo == user.uid)
                              .toList();
                          
                          if (myAssignments.isEmpty) {
                            return Padding(
                              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                              child: Text(
                                'No assignments found for you in this week.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: isSmallScreen ? 13 : null,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          
                          final myCompleted = myAssignments.where((a) => a.isCompleted).length;
                          final myInProgress = myAssignments.where((a) => a.status == 'ongoing').length;
                          final myNotStarted = myAssignments.where((a) => a.status == 'pending').length;
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // My progress summary
                              Card(
                                elevation: 0,
                                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                child: Padding(
                                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'My Progress',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontSize: isSmallScreen ? 14 : null,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 6 : 8),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 8,
                                        children: [
                                          if (myCompleted > 0)
                                            Chip(
                                              avatar: const Icon(Icons.check_circle, size: 16),
                                              label: Text('$myCompleted Completed'),
                                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                            ),
                                          if (myInProgress > 0)
                                            Chip(
                                              avatar: const Icon(Icons.hourglass_bottom, size: 16),
                                              label: Text('$myInProgress In Progress'),
                                              backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                                            ),
                                          if (myNotStarted > 0)
                                            Chip(
                                              avatar: const Icon(Icons.radio_button_unchecked, size: 16),
                                              label: Text('$myNotStarted Not Started'),
                                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: isSmallScreen ? 12 : 16),
                              // My assignments list
                              ...myAssignments.map((assignment) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 2 : 4),
                        child: Row(
                          children: [
                            Icon(
                              assignment.isCompleted
                                  ? Icons.check_circle
                                            : assignment.status == 'ongoing'
                                                ? Icons.hourglass_bottom
                                  : Icons.radio_button_unchecked,
                              size: isSmallScreen ? 18 : 20,
                              color: assignment.isCompleted
                                  ? Theme.of(context).colorScheme.primary
                                            : assignment.status == 'ongoing'
                                                ? Theme.of(context).colorScheme.tertiary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 12),
                            Expanded(
                              child: Text(
                                          'Juz ${assignment.juzNumber.toInt()} - ${statusLabel(assignment.status)}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: isSmallScreen ? 13 : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_showCelebration)
          Positioned.fill(
            child: CelebrationWidget(
              onComplete: () {
                setState(() {
                  _showCelebration = false;
                });
              },
            ),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 12,
        vertical: isSmallScreen ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 13 : null,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: isSmallScreen ? 10 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStatisticsCard extends StatefulWidget {
  const _WeekStatisticsCard({
    required this.groupId,
    required this.weekId,
    required this.weeklyService,
    required this.isAdmin,
  });

  final String groupId;
  final String weekId;
  final WeeklyAssignmentService weeklyService;
  final bool isAdmin;

  @override
  State<_WeekStatisticsCard> createState() => _WeekStatisticsCardState();
}

class _WeekStatisticsCardState extends State<_WeekStatisticsCard> {
  Map<String, dynamic>? _stats;
  List<RecitationAssignment>? _assignments;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await widget.weeklyService.getWeekStatistics(
        groupId: widget.groupId,
        weekId: widget.weekId,
      );
      final assignments = await widget.weeklyService.getWeekAssignments(
        groupId: widget.groupId,
        weekId: widget.weekId,
      );

      if (mounted) {
        setState(() {
          _stats = stats;
          _assignments = assignments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final weekNumber = widget.weeklyService.getWeekNumberFromId(widget.weekId);

    if (_isLoading) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_stats == null || _assignments == null) {
      return const SizedBox.shrink();
    }

    final uniqueJuzCompleted = _stats!['unique_juz_completed'] as int;
    final totalAssignments = _stats!['total_assignments'] as int;
    final completedAssignments = _stats!['completed_assignments'] as int;
    final completionRate = _stats!['completion_rate'] as double;

    // Calculate member statistics
    final memberStats = <String, Map<String, int>>{};
    for (final assignment in _assignments!) {
      if (!memberStats.containsKey(assignment.assignedTo)) {
        memberStats[assignment.assignedTo] = {
          'total': 0,
          'completed': 0,
          'in_progress': 0,
          'pending': 0,
        };
      }
      final stats = memberStats[assignment.assignedTo]!;
      stats['total'] = stats['total']! + 1;
      if (assignment.isCompleted) {
        stats['completed'] = stats['completed']! + 1;
      } else if (assignment.status == 'ongoing') {
        stats['in_progress'] = stats['in_progress']! + 1;
      } else {
        stats['pending'] = stats['pending']! + 1;
      }
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Week ${weekNumber ?? 'N/A'} Statistics',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 18 : null,
                        ),
                  ),
                ),
                RefreshButton(
                  onRefresh: _loadStatistics,
                  tooltip: 'Refresh statistics',
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Juz Completed',
                    value: '$uniqueJuzCompleted/30',
                    icon: Icons.menu_book,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: _StatCard(
                    label: 'Completion Rate',
                    value: '${(completionRate * 100).toStringAsFixed(0)}%',
                    icon: Icons.check_circle,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Assignments',
                    value: '$totalAssignments',
                    icon: Icons.assignment,
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: _StatCard(
                    label: 'Completed',
                    value: '$completedAssignments',
                    icon: Icons.done_all,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
              ],
            ),
            if (widget.isAdmin && memberStats.isNotEmpty) ...[
              SizedBox(height: isSmallScreen ? 16 : 20),
              const Divider(),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                'Member Performance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 16 : null,
                    ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              ...memberStats.entries.map((entry) {
                final memberId = entry.key;
                final stats = entry.value;
                final memberAssignment = _assignments!.firstWhere(
                  (a) => a.assignedTo == memberId,
                );
                final memberName = memberAssignment.assignedToName;
                final memberCompletionRate = stats['total']! > 0
                    ? (stats['completed']! / stats['total']!)
                    : 0.0;

                return Card(
                  elevation: 0,
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: isSmallScreen ? 16 : 20,
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: Text(
                                memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 12 : 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    memberName,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: isSmallScreen ? 14 : null,
                                        ),
                                  ),
                                  Text(
                                    '${stats['completed']}/${stats['total']} completed',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontSize: isSmallScreen ? 11 : null,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(memberCompletionRate * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: isSmallScreen ? 16 : null,
                                  ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        LinearProgressIndicator(
                          value: memberCompletionRate,
                          minHeight: isSmallScreen ? 6 : 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isSmallScreen,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isSmallScreen;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: isSmallScreen ? 24 : 28),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 20 : null,
                  ),
            ),
            SizedBox(height: isSmallScreen ? 2 : 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: isSmallScreen ? 11 : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

