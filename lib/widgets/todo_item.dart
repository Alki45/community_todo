import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/recitation_model.dart';
import '../providers/quran_provider.dart';

Color statusColor(String status, ColorScheme scheme) {
  switch (status) {
    case 'completed':
      return scheme.secondaryContainer;
    case 'ongoing':
      return scheme.tertiaryContainer;
    case 'pending':
    default:
      return scheme.surfaceContainerHighest;
  }
}

String statusLabel(String status) {
  switch (status) {
    case 'completed':
      return 'Completed';
    case 'ongoing':
      return 'In progress';
    case 'pending':
    default:
      return 'Pending';
  }
}

IconData statusIcon(String status) {
  switch (status) {
    case 'completed':
      return Icons.check_circle;
    case 'ongoing':
      return Icons.hourglass_bottom;
    case 'pending':
    default:
      return Icons.radio_button_unchecked;
  }
}

class TodoItem extends StatelessWidget {
  const TodoItem({
    super.key,
    required this.assignment,
    this.onMarkCompleted,
    this.onMarkInProgress,
    this.onReset,
  });

  final RecitationAssignment assignment;
  final VoidCallback? onMarkCompleted;
  final VoidCallback? onMarkInProgress;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final quranProvider = context.watch<QuranProvider>();
    final deadline = assignment.deadline != null
        ? DateFormat.yMMMd().format(assignment.deadline!)
        : null;
    final versePreview = (assignment.surah != null && assignment.ayatRange != null)
        ? quranProvider.verseText(
            assignment.surah!,
            assignment.ayatRange!,
            maxAyat: 3,
          )
        : '';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: statusColor(assignment.status, colorScheme),
                  child: Icon(
                    statusIcon(assignment.status),
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.surah ?? 'Juz ${assignment.juzNumber}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (assignment.ayatRange != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Ayat ${assignment.ayatRange}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ] else if (assignment.surah != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Juz ${assignment.juzNumber}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.menu_book, size: 16),
                  label: Text('Juz ${assignment.juzNumber}'),
                  backgroundColor: colorScheme.primaryContainer,
                ),
                const SizedBox(width: 8),
                Chip(
                  avatar: const Icon(Icons.auto_stories, size: 16),
                  label: Text(statusLabel(assignment.status)),
                  backgroundColor: statusColor(assignment.status, colorScheme),
                ),
              ],
            ),
            if (versePreview.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                versePreview,
                textDirection: ui.TextDirection.rtl,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoChip(
                  icon: Icons.group,
                  label: 'Group',
                  value: assignment.groupName.isEmpty
                      ? assignment.groupId
                      : assignment.groupName,
                ),
                _InfoChip(
                  icon: Icons.person,
                  label: 'Assigned by',
                  value: assignment.assignedByName.isEmpty
                      ? assignment.assignedBy
                      : assignment.assignedByName,
                ),
                if (deadline != null)
                  _InfoChip(
                    icon: Icons.event,
                    label: 'Deadline',
                    value: deadline,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onMarkCompleted != null)
                  FilledButton.icon(
                    onPressed: onMarkCompleted,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Mark completed'),
                  )
                else
                  FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Completed'),
                  ),
                if (onMarkInProgress != null)
                  OutlinedButton.icon(
                    onPressed: onMarkInProgress,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('In progress'),
                  )
                else if (assignment.status == 'ongoing')
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.hourglass_bottom, size: 18),
                    label: const Text('In progress'),
                  ),
                if (onReset != null)
                  TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text('$label: $value'),
    );
  }
}

class TodoLegend extends StatelessWidget {
  const TodoLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      ('Completed', statusColor('completed', scheme)),
      ('In progress', statusColor('ongoing', scheme)),
      ('Pending', statusColor('pending', scheme)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => Chip(
              label: Text(item.$1),
              backgroundColor: item.$2,
            ),
          )
          .toList(),
    );
  }
}
