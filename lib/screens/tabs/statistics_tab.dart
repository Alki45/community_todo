import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/group_model.dart';
import '../../models/group_statistics.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';

// ========================
// Aggregated Statistics Helper
// ========================
class _AggregatedStatistics {
  final int totalAssignments;
  final int completedAssignments;
  final int pendingAssignments;
  final int juzCompleted;
  final double juzProgress;
  final double completionRate;
  final List<MemberProgress> membersProgress;

  _AggregatedStatistics({
    required this.totalAssignments,
    required this.completedAssignments,
    required this.pendingAssignments,
    required this.juzCompleted,
    required this.juzProgress,
    required this.completionRate,
    required this.membersProgress,
  });
}

_AggregatedStatistics _mergeStatistics(Iterable<GroupStatistics> statsList) {
  int totalAssignments = 0;
  int completedAssignments = 0;
  int pendingAssignments = 0;
  int juzCompleted = 0;
  double totalJuzProgress = 0.0;
  final members = <MemberProgress>[];

  int countWithJuzProgress = 0;

  for (final s in statsList) {
    totalAssignments += s.totalAssignments;
    completedAssignments += s.completedAssignments;
    pendingAssignments += s.pendingAssignments;
    juzCompleted += s.juzCompleted;
    totalJuzProgress += s.juzProgress;
    countWithJuzProgress++;
    members.addAll(s.membersProgress);
  }

  final avgJuzProgress = countWithJuzProgress > 0
      ? totalJuzProgress / countWithJuzProgress
      : 0.0;

  final completionRate =
      totalAssignments > 0 ? (completedAssignments / totalAssignments) : 0.0;

  members.sort((a, b) => b.completionRate.compareTo(a.completionRate));

  return _AggregatedStatistics(
    totalAssignments: totalAssignments,
    completedAssignments: completedAssignments,
    pendingAssignments: pendingAssignments,
    juzCompleted: juzCompleted,
    juzProgress: avgJuzProgress.clamp(0.0, 1.0),
    completionRate: completionRate.clamp(0.0, 1.0),
    membersProgress: members,
  );
}

// ========================
// Main Statistics Tab
// ========================
class StatisticsTab extends StatefulWidget {
  const StatisticsTab({super.key});

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab> {
  String? _selectedGroupId;
  final Map<String, GroupStatistics> _groupStatsMap = {};
  final Map<String, StreamSubscription<GroupStatistics>> _subscriptions = {};

  @override
  void dispose() {
    for (final sub in _subscriptions.values) sub.cancel();
    super.dispose();
  }

  void _subscribeToGroups(List<Group> groups, FirestoreService firestore) {
    final groupIds = groups.map((g) => g.id).toSet();
    final toRemove =
        _subscriptions.keys.where((id) => !groupIds.contains(id)).toList();
    for (final id in toRemove) {
      _subscriptions[id]?.cancel();
      _subscriptions.remove(id);
      _groupStatsMap.remove(id);
    }

    for (final g in groups) {
      if (_subscriptions.containsKey(g.id)) continue;
      final sub = firestore.watchGroupStatistics(g).listen((stats) {
        setState(() {
          _groupStatsMap[g.id] = stats;
        });
      }, onError: (_) {});
      _subscriptions[g.id] = sub;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;
    final firestore = context.read<FirestoreService>();

    if (userProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (user == null) {
      return const Center(
        child: Text('Sign in to review community statistics.'),
      );
    }

    return StreamBuilder<List<Group>>(
      stream: firestore.watchUserGroups(user.uid),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        if (isLoading) return const Center(child: CircularProgressIndicator());

        if (groups.isEmpty) {
          return const Center(child: Text('No groups yet.'));
        }

        _subscribeToGroups(groups, firestore);

        if (_selectedGroupId == null ||
            (_selectedGroupId != 'all' &&
                !groups.any((g) => g.id == _selectedGroupId))) {
          final providerActive = userProvider.activeGroupId;
          if (providerActive != null &&
              groups.any((g) => g.id == providerActive)) {
            _selectedGroupId = providerActive;
          } else {
            _selectedGroupId = groups.first.id;
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => userProvider.setActiveGroup(_selectedGroupId!));
          }
        }

        final Group? selectedGroup = _selectedGroupId == 'all'
            ? null
            : groups.firstWhere((g) => g.id == _selectedGroupId,
                orElse: () => groups.first);

        final _AggregatedStatistics? aggregated = _selectedGroupId == 'all'
            ? (_groupStatsMap.values.isNotEmpty
                ? _mergeStatistics(_groupStatsMap.values)
                : null)
            : null;
        final GroupStatistics? selectedStats =
            (_selectedGroupId != 'all') ? _groupStatsMap[_selectedGroupId!] : null;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Group statistics',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
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
                          items: [
                            const DropdownMenuItem(
                                value: 'all',
                                child: Text('All groups (aggregated)')),
                            ...groups.map((group) => DropdownMenuItem(
                                value: group.id, child: Text(group.name))),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedGroupId = value);
                              if (value != 'all') userProvider.setActiveGroup(value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _selectedGroupId == 'all'
                    ? (aggregated == null
                        ? const Center(child: CircularProgressIndicator())
                        : _AggregatedStatisticsView(
                            aggregated: aggregated,
                            groupsCount: groups.length,
                          ))
                    : _PerGroupStatisticsView(
                        group: selectedGroup!,
                        statistics: selectedStats,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ========================
// Aggregated Stats View
// ========================
class _AggregatedStatisticsView extends StatelessWidget {
  const _AggregatedStatisticsView({
    required this.aggregated,
    required this.groupsCount,
  });

  final _AggregatedStatistics aggregated;
  final int groupsCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('All groups',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('$groupsCount groups • Aggregated view',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Overall Progress'),
                  Text('${(aggregated.completionRate * 100).toStringAsFixed(1)}% Complete',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary)),
                ],
              ),
            ),
            Text('${aggregated.completedAssignments}/${aggregated.totalAssignments}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: aggregated.completionRate.clamp(0.0, 1.0),
          minHeight: 12,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(colorScheme.primary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatisticChip(
                label: 'Total Assignments',
                value: aggregated.totalAssignments,
                icon: Icons.list_alt_outlined),
            _StatisticChip(
                label: 'Completed',
                value: aggregated.completedAssignments,
                icon: Icons.check_circle_outline,
                color: colorScheme.primaryContainer),
            _StatisticChip(
                label: 'Pending',
                value: aggregated.pendingAssignments,
                icon: Icons.pending_actions_outlined,
                color: colorScheme.tertiaryContainer),
            _StatisticChip(
                label: 'Juz Completed',
                value: aggregated.juzCompleted,
                suffix: '/30',
                icon: Icons.menu_book,
                color: colorScheme.secondaryContainer),
            _StatisticChip(
                label: 'Juz Progress',
                value: (aggregated.juzProgress * 100).round(),
                suffix: '%',
                icon: Icons.trending_up),
            _StatisticChip(
                label: 'Completion Rate',
                value: (aggregated.completionRate * 100).round(),
                suffix: '%',
                icon: Icons.percent),
          ],
        ),
        const SizedBox(height: 20),
        Text('Top members (aggregated)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (aggregated.membersProgress.isEmpty)
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('No member assignments across groups yet.')),
                ],
              ),
            ),
          )
        else
          ...aggregated.membersProgress.take(5).map(
                (p) => _MemberProgressCard(progress: p, isTopPerformer: aggregated.membersProgress.indexOf(p) == 0),
              ),
      ],
    );
  }
}

// ========================
// Statistic Chip Widget
// ========================
class _StatisticChip extends StatelessWidget {
  const _StatisticChip({
    required this.label,
    required this.value,
    required this.icon,
    this.suffix,
    this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final String? suffix;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = color ?? colorScheme.secondaryContainer;

    return Chip(
      avatar: Icon(icon, size: 18, color: colorScheme.onSecondaryContainer),
      backgroundColor: backgroundColor,
      labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value${suffix ?? ''}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ========================
// Member Progress Card
// ========================
class _MemberProgressCard extends StatelessWidget {
  const _MemberProgressCard({
    required this.progress,
    this.isTopPerformer = false,
    super.key,
  });

  final MemberProgress progress;
  final bool isTopPerformer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: isTopPerformer ? colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(child: Text(progress.name[0].toUpperCase())),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(progress.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress.completionRate,
                    minHeight: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${(progress.completionRate * 100).round()}%',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

// ========================
// Per-Group Statistics View
// ========================
class _PerGroupStatisticsView extends StatelessWidget {
  const _PerGroupStatisticsView({
    required this.group,
    required this.statistics,
  });

  final Group group;
  final GroupStatistics? statistics;

  @override
  Widget build(BuildContext context) {
    if (statistics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(group.name,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: statistics!.completionRate,
          minHeight: 12,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatisticChip(
              label: 'Total Assignments',
              value: statistics!.totalAssignments,
              icon: Icons.list_alt_outlined,
            ),
            _StatisticChip(
              label: 'Completed',
              value: statistics!.completedAssignments,
              icon: Icons.check_circle_outline,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            _StatisticChip(
              label: 'Pending',
              value: statistics!.pendingAssignments,
              icon: Icons.pending_actions_outlined,
              color: Theme.of(context).colorScheme.tertiaryContainer,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Members progress',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (statistics!.membersProgress.isEmpty)
          const Text('No assignments for members yet.')
        else
          ...statistics!.membersProgress
              .map((p) => _MemberProgressCard(progress: p)),
      ],
    );
  }
}
