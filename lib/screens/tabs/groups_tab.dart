import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/group_model.dart';
import '../../models/join_request.dart';
import '../../models/user_model.dart';
import '../../models/recitation_model.dart';
import '../../providers/user_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/weekly_assignment_service.dart';
import '../../widgets/refresh_button.dart';
import '../../screens/group_chat_screen.dart';

class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});

  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  bool _isProcessing = false;

  FirestoreService get _firestore => context.read<FirestoreService>();
  NotificationService get _notifications => context.read<NotificationService>();

  Future<void> _createGroup(AppUser user) async {
    final result = await showModalBottomSheet<_GroupFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => GroupFormSheet(
        title: 'Create a new group',
        primaryActionLabel: 'Create group',
      ),
    );

    if (result == null) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final group = await _firestore.createGroup(
        name: result.name,
        creator: user,
        description: result.description,
        isPublic: result.isPublic,
        requiresApproval: result.requiresApproval,
      );
      await _notifications.subscribeToGroupTopic(group.id);
      if (mounted) {
        _showSnackBar('Group "${group.name}" created successfully.');
      }
    } catch (error) {
      if (mounted) {
        String errorMessage = 'Failed to create group. ';
        if (error is StateError) {
          errorMessage += error.message;
        } else if (error is ArgumentError) {
          errorMessage += error.message ?? error.toString();
        } else {
          errorMessage += error.toString();
        }
        _showSnackBar(errorMessage, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _joinGroup(AppUser user) async {
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const JoinGroupSheet(),
    );

    if (result == null) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      Group group;
      if (result is _JoinGroupResult) {
        try {
          group = await _firestore.joinGroupByCode(
            user: user,
            inviteCode: result.inviteCode,
          );
          await _notifications.subscribeToGroupTopic(group.id);
          await _notifications.showLocalNotification(
            'Joined group',
            'You have successfully joined ${group.name}.',
          );
          if (mounted) {
            _showSnackBar('Joined ${group.name}.');
          }
        } catch (error) {
          // Check if it's a join request error
          if (error.toString().contains('Join request sent') ||
              error.toString().contains('Waiting for admin approval')) {
            await _notifications.showLocalNotification(
              'Join request sent',
              'Your request has been sent. Waiting for admin approval.',
            );
          }
          rethrow;
        }
      } else if (result is _JoinGroupLinkResult) {
        try {
          group = await _firestore.joinGroupByLink(user: user, link: result.link);
          await _notifications.subscribeToGroupTopic(group.id);
          await _notifications.showLocalNotification(
            'Joined group',
            'You have successfully joined ${group.name}.',
          );
          if (mounted) {
            _showSnackBar('Joined ${group.name}.');
          }
        } catch (error) {
          // Check if it's a join request error
          if (error.toString().contains('Join request sent') ||
              error.toString().contains('Waiting for admin approval')) {
            await _notifications.showLocalNotification(
              'Join request sent',
              'Your request has been sent. Waiting for admin approval.',
            );
          }
          rethrow;
        }
      } else {
        return;
      }
    } catch (error) {
      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _leaveGroup(AppUser user, Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave group'),
        content: Text(
          'Are you sure you want to leave "${group.name}"? '
          'You will lose access to group assignments and statistics.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Leave group'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await _firestore.leaveGroup(user: user, group: group);
      await _notifications.unsubscribeFromGroupTopic(group.id);
      if (mounted) {
        _showSnackBar('You have left ${group.name}.');
      }
    } catch (error) {
      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _assignWeeklyJuz({
    required Group group,
    required GroupMember admin,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Weekly Juz'),
        content: Text(
          'This will assign all 30 Juz of the Quran to group members for this week. '
          'Each member will receive an equal share of the 30 Juz. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final weeklyService = WeeklyAssignmentService(FirebaseFirestore.instance);
      await weeklyService.assignWeeklyJuz(
        group: group,
        assignedBy: admin,
      );
      await _notifications.showLocalNotification(
        'Weekly assignments created',
        'All 30 Juz have been assigned to group members for this week.',
      );
      if (mounted) {
        _showSnackBar('Weekly Juz assignments created successfully.');
      }
    } catch (error) {
      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _assignRecitation({
    required Group group,
    required GroupMember admin,
  }) async {
    final result = await showModalBottomSheet<_AssignmentFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AssignmentFormSheet(group: group, admin: admin),
    );

    if (result == null) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final member = group.members.firstWhere(
        (element) => element.uid == result.memberUid,
      );
      final assignment = await _firestore.assignRecitation(
        group: group,
        assignedTo: member,
        assignedBy: admin,
        surah: result.surah,
        ayatRange: result.ayatRange,
        juzNumber: result.juzNumber,
        deadline: result.deadline,
      );
      final assignmentDesc = [
        'Juz ${assignment.juzNumber}',
        if (assignment.surah != null) assignment.surah!,
        if (assignment.ayatRange != null) '(${assignment.ayatRange})',
      ].join(' ');
      
      // Show notification to the person who assigned it (admin)
      await _notifications.showLocalNotification(
        'Recitation assigned',
        'You assigned $assignmentDesc to ${assignment.assignedToName}.',
      );
      if (mounted) {
        _showSnackBar('Recitation assigned to ${member.name}.');
      }
    } catch (error) {
      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _voteForAdmin({
    required Group group,
    required GroupMember candidate,
    required String voterUid,
  }) async {
    setState(() => _isProcessing = true);
    try {
      await _firestore.voteForAdmin(
        group: group,
        candidateUid: candidate.uid,
        voterUid: voterUid,
      );
      await _notifications.showLocalNotification(
        'Admin vote submitted',
        'Your vote for ${candidate.name} has been recorded.',
      );
    } catch (error) {
      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _addMember({
    required Group group,
    required AppUser newMember,
  }) async {
    setState(() => _isProcessing = true);
    try {
      final updatedGroup = await _firestore.addMemberToGroup(
        group: group,
        member: newMember,
      );
      await _notifications.showLocalNotification(
        'New group member',
        '${newMember.name.isEmpty ? newMember.email : newMember.name} joined ${group.name}.',
      );
      if (mounted) {
        _showSnackBar(
          '${newMember.name.isEmpty ? newMember.email : newMember.name} added to ${group.name}.',
        );
        // Close the detail sheet to refresh the group list
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(error.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _setAdmin({
    required Group group,
    required GroupMember target,
  }) async {
    setState(() => _isProcessing = true);
    try {
      await _firestore.setAdmin(groupId: group.id, adminUid: target.uid);
      await _notifications.showLocalNotification(
        'Admin updated',
        '${target.name} is now the group admin.',
      );
    } catch (error) {
      _showSnackBar(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _removeMember({
    required Group group,
    required GroupMember member,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member'),
        content: Text(
          'Are you sure you want to remove "${member.name.isEmpty ? member.email : member.name}" from "${group.name}"? '
          'Their assignment history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) return;

      await _firestore.removeMemberFromGroup(
        group: group,
        memberUid: member.uid,
        adminUid: user.uid,
      );
      if (mounted) {
        _showSnackBar(
          '${member.name.isEmpty ? member.email : member.name} removed from ${group.name}.',
        );
        Navigator.of(context).pop(); // Close detail sheet
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(error.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _deleteGroup(Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group'),
        content: Text(
          'Are you sure you want to delete "${group.name}"? '
          'This action cannot be undone. All members will be removed, but assignment history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete group'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) return;

      await _firestore.deleteGroup(
        group: group,
        adminUid: user.uid,
      );
      await _notifications.unsubscribeFromGroupTopic(group.id);
      if (mounted) {
        _showSnackBar('Group "${group.name}" deleted.');
        Navigator.of(context).pop(); // Close detail sheet
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(error.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _openGroupChat(Group group) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupChatScreen(group: group),
      ),
    );
  }

  void _openGroupDetail(AppUser user, Group group) {
    final userProvider = context.read<UserProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => GroupDetailSheet(
        user: user,
        group: group,
        isActiveGroup: userProvider.activeGroupId == group.id,
        onLeave: () => _leaveGroup(user, group),
        onAssignRecitation: () => _assignRecitation(
          group: group,
          admin: group.members.firstWhere(
            (element) => element.uid == group.adminUid,
          ),
        ),
        onAssignWeeklyJuz: () => _assignWeeklyJuz(
          group: group,
          admin: group.members.firstWhere(
            (element) => element.uid == group.adminUid,
          ),
        ),
        onVoteForAdmin: (candidate) => _voteForAdmin(
          group: group,
          candidate: candidate,
          voterUid: user.uid,
        ),
        onSetAdmin: (candidate) => _setAdmin(group: group, target: candidate),
        onAddMember: (member) => _addMember(group: group, newMember: member),
        onRemoveMember: (member) => _removeMember(group: group, member: member),
        onDeleteGroup: () => _deleteGroup(group),
        onSetActiveGroup: () => userProvider.setActiveGroup(group.id),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final user = userProvider.user;

    if (userProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (user == null) {
      return const Center(child: Text('Sign in to manage recitation groups.'));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isProcessing ? null : () => _createGroup(user),
        icon: const Icon(Icons.add),
        label: const Text('New group'),
      ),
      body: Stack(
        children: [
          StreamBuilder<List<Group>>(
            stream: _firestore.watchUserGroups(user.uid),
            builder: (context, snapshot) {
              final groups = snapshot.data ?? [];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              final isSmallScreen = MediaQuery.of(context).size.height < 700;

              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 600 ? 24 : 16,
                  vertical: isSmallScreen ? 16 : 24,
                ),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _GroupsHeader(
                          onCreateGroup: () => _createGroup(user),
                          onJoinGroup: () => _joinGroup(user),
                          isProcessing: _isProcessing,
                        ),
                      ),
                      RefreshButton(
                        onRefresh: () async {
                          await userProvider.refreshUser();
                        },
                        tooltip: 'Refresh groups',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MySentRequestsSection(user: user),
                  const SizedBox(height: 16),
                  if (isLoading)
                    const Card(
                      elevation: 0,
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (groups.isEmpty)
                    const _EmptyGroupsCard()
                  else ...[
                    Text(
                      'My Groups',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    for (final group in groups)
                      GroupListTile(
                        group: group,
                        currentUserId: user.uid,
                        isActive: userProvider.activeGroupId == group.id,
                        onTap: () => _openGroupDetail(user, group),
                        onChat: () => _openGroupChat(group),
                      ),
                  ],
                ],
              );
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withAlpha((0.2 * 255).round()),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _GroupsHeader extends StatelessWidget {
  const _GroupsHeader({
    required this.onCreateGroup,
    required this.onJoinGroup,
    required this.isProcessing,
  });

  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recitation groups',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: isSmallScreen ? 16 : null,
              ),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              'Create a group for your family, halaqah, or community. '
              'Invite members to collaborate, assign recitations, and track progress together.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: isSmallScreen ? 13 : null,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: isProcessing ? null : onCreateGroup,
                  icon: const Icon(Icons.group_add),
                  label: const Text('Create group'),
                ),
                OutlinedButton.icon(
                  onPressed: isProcessing ? null : onJoinGroup,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Join via invite code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGroupsCard extends StatelessWidget {
  const _EmptyGroupsCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_outlined, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'No groups yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Create a group and invite members, or join an existing group using an invite code.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class GroupListTile extends StatelessWidget {
  const GroupListTile({
    super.key,
    required this.group,
    required this.currentUserId,
    required this.onTap,
    this.isActive = false,
    this.onChat,
  });

  final Group group;
  final String currentUserId;
  final VoidCallback onTap;
  final bool isActive;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    GroupMember? adminMember;
    if (group.members.isNotEmpty) {
      adminMember = group.members.firstWhere(
        (member) => member.uid == group.adminUid,
        orElse: () => group.members.first,
      );
    }

    final isAdmin = group.adminUid == currentUserId;
    final chips = <Widget>[];

    if (isAdmin) {
      chips.add(
        const Chip(label: Text('Admin'), avatar: Icon(Icons.star, size: 16)),
      );
    }
    if (isActive) {
      chips.add(
        const Chip(label: Text('Home'), avatar: Icon(Icons.home, size: 16)),
      );
    }

    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Card(
      elevation: 0,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 24,
          vertical: isSmallScreen ? 8 : 12,
        ),
        leading: CircleAvatar(
          radius: isSmallScreen ? 20 : 24,
          child: Text(
            group.name.isEmpty ? '?' : group.name[0].toUpperCase(),
            style: TextStyle(fontSize: isSmallScreen ? 14 : null),
          ),
        ),
        title: Text(
          group.name,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: isSmallScreen ? 16 : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${group.memberCount} members • Admin: ${adminMember?.name ?? 'Unassigned'}',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(fontSize: isSmallScreen ? 12 : null),
            ),
            SizedBox(height: isSmallScreen ? 2 : 4),
            _GroupAssignmentSummary(
              groupId: group.id,
              currentUserId: currentUserId,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onChat != null)
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Open group chat',
                onPressed: () {
                  onChat?.call();
                },
                iconSize: isSmallScreen ? 20 : 24,
              ),
            if (chips.isEmpty)
              Icon(
                Icons.chevron_right,
                size: isSmallScreen ? 20 : 24,
              )
            else
              Wrap(
                spacing: isSmallScreen ? 4 : 8,
                runSpacing: isSmallScreen ? 4 : 8,
                children: chips,
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _GroupAssignmentSummary extends StatelessWidget {
  const _GroupAssignmentSummary({
    required this.groupId,
    required this.currentUserId,
  });

  final String groupId;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final firestore = context.read<FirestoreService>();

    return StreamBuilder<List<RecitationAssignment>>(
      stream: firestore.watchMemberAssignments(currentUserId, groupId: groupId),
      builder: (context, snapshot) {
        final assignments = snapshot.data ?? [];
        final waiting =
            snapshot.connectionState == ConnectionState.waiting &&
            assignments.isEmpty;

        if (waiting) {
          return Text(
            'Loading assignments…',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          );
        }

        if (assignments.isEmpty) {
          return Text(
            'No personal assignments yet.',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          );
        }

        final completed = assignments
            .where((assignment) => assignment.isCompleted)
            .length;
        final ongoing = assignments
            .where((assignment) => assignment.status == 'ongoing')
            .length;
        final pending = assignments.length - completed - ongoing;
        final completionRate = assignments.isEmpty
            ? 0
            : ((completed / assignments.length) * 100).round();

        final isSmallScreen = MediaQuery.of(context).size.height < 700;
        return Text(
          'Assignments: $completed completed • $ongoing in progress • $pending pending • $completionRate% done',
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontSize: isSmallScreen ? 11 : null,
          ),
        );
      },
    );
  }
}

class GroupDetailSheet extends StatelessWidget {
  const GroupDetailSheet({
    super.key,
    required this.user,
    required this.group,
    required this.onAssignRecitation,
    required this.onAssignWeeklyJuz,
    required this.onLeave,
    required this.onVoteForAdmin,
    required this.onSetAdmin,
    required this.onAddMember,
    required this.onRemoveMember,
    required this.onDeleteGroup,
    required this.onSetActiveGroup,
    required this.isActiveGroup,
  });

  final AppUser user;
  final Group group;
  final VoidCallback onAssignRecitation;
  final VoidCallback onAssignWeeklyJuz;
  final VoidCallback onLeave;
  final ValueChanged<GroupMember> onVoteForAdmin;
  final ValueChanged<GroupMember> onSetAdmin;
  final ValueChanged<AppUser> onAddMember;
  final ValueChanged<GroupMember> onRemoveMember;
  final VoidCallback onDeleteGroup;
  final VoidCallback onSetActiveGroup;
  final bool isActiveGroup;

  @override
  Widget build(BuildContext context) {
    final isAdmin = group.adminUid == user.uid;
    final adminVotes = group.adminVotes;
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      maxChildSize: 0.95,
      initialChildSize: 0.8,
      builder: (context, controller) {
        final isSmallScreenLocal = MediaQuery.of(context).size.height < 700;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.all(isSmallScreenLocal ? 16 : 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Text(
              group.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: isSmallScreenLocal ? 20 : null,
              ),
            ),
            SizedBox(height: isSmallScreenLocal ? 6 : 8),
            if (group.shareableLink != null) ...[
              Text(
                'Shareable link: ${group.shareableLink}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: isSmallScreenLocal ? 13 : null,
                ),
              ),
              SizedBox(height: isSmallScreenLocal ? 6 : 8),
            ],
            Text(
              'Invite code: ${group.inviteCode}',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: isSmallScreenLocal ? 13 : null,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (group.shareableLink != null)
                  FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: group.shareableLink!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Group link copied to clipboard'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Copy link'),
                  ),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: group.inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invite code copied to clipboard'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy code'),
                ),
                if (group.isPublic)
                  const Chip(
                    label: Text('Public group'),
                    avatar: Icon(Icons.public, size: 16),
                  ),
                if (group.requiresApproval)
                  const Chip(
                    label: Text('Requires approval'),
                    avatar: Icon(Icons.verified_user, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (!isActiveGroup)
              TextButton.icon(
                onPressed: onSetActiveGroup,
                icon: const Icon(Icons.push_pin_outlined),
                label: const Text('Make this my home group'),
              )
            else
              const Chip(
                label: Text('Current home group'),
                avatar: Icon(Icons.home, size: 16),
              ),
            SizedBox(height: isSmallScreenLocal ? 16 : 24),
            Text(
              'Members',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: isSmallScreenLocal ? 16 : null,
              ),
            ),
            SizedBox(height: isSmallScreenLocal ? 8 : 12),
            for (final member in group.members)
              Card(
                elevation: 0,
                child: ListTile(
                  leading: CircleAvatar(
                    radius: isSmallScreenLocal ? 18 : 20,
                    child: Text(
                      member.name.isEmpty ? '?' : member.name[0].toUpperCase(),
                      style: TextStyle(fontSize: isSmallScreenLocal ? 12 : null),
                    ),
                  ),
                  title: Text(
                    member.name.isEmpty ? member.email : member.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(fontSize: isSmallScreenLocal ? 14 : null),
                  ),
                  subtitle: Text(
                    'Joined ${DateFormat.yMMMd().format(member.joinedAt)}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(fontSize: isSmallScreenLocal ? 12 : null),
                  ),
                  trailing: _MemberActions(
                    isAdmin: isAdmin,
                    isCurrentUser: member.uid == user.uid,
                    isCurrentAdmin: member.uid == group.adminUid,
                    onVote: () => onVoteForAdmin(member),
                    onSetAdmin: () => onSetAdmin(member),
                    onRemove: () => onRemoveMember(member),
                    voteCount: adminVotes[member.uid]?.length ?? 0,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (isAdmin) ...[
              FilledButton.icon(
                onPressed: onAssignWeeklyJuz,
                icon: const Icon(Icons.calendar_today),
                label: const Text('Assign Weekly Juz (30 Juz)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAssignRecitation,
                icon: const Icon(Icons.assignment_add),
                label: const Text('Assign individual recitation'),
              ),
            ],
            if (isAdmin) ...[
              const SizedBox(height: 24),
              _JoinRequestsSection(group: group, user: user),
              const SizedBox(height: 24),
              Text(
                'Invite members',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              GroupMemberSearch(group: group, onUserSelected: onAddMember),
            ],
            const SizedBox(height: 16),
            if (isAdmin) ...[
              OutlinedButton.icon(
                onPressed: onDeleteGroup,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete group'),
              ),
              const SizedBox(height: 12),
            ],
            if (!isAdmin)
              OutlinedButton.icon(
                onPressed: onLeave,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Leave group'),
              ),
          ],
        ),
      );
      },
    );
  }
}

class _MemberActions extends StatelessWidget {
  const _MemberActions({
    required this.isAdmin,
    required this.isCurrentAdmin,
    required this.isCurrentUser,
    required this.onVote,
    required this.onSetAdmin,
    required this.onRemove,
    required this.voteCount,
  });

  final bool isAdmin;
  final bool isCurrentAdmin;
  final bool isCurrentUser;
  final VoidCallback onVote;
  final VoidCallback onSetAdmin;
  final VoidCallback onRemove;
  final int voteCount;

  @override
  Widget build(BuildContext context) {
    if (isCurrentAdmin) {
      return const Chip(
        avatar: Icon(Icons.star, size: 16),
        label: Text('Admin'),
      );
    }

    if (isCurrentUser) {
      return Chip(
        avatar: const Icon(Icons.how_to_vote, size: 16),
        label: Text('Votes: $voteCount'),
      );
    }

    if (isAdmin) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: onSetAdmin,
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Make admin'),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.person_remove),
            tooltip: 'Remove member',
            color: Theme.of(context).colorScheme.error,
          ),
        ],
      );
    }

    return TextButton.icon(
      onPressed: onVote,
      icon: const Icon(Icons.how_to_vote),
      label: Text('Vote ($voteCount)'),
    );
  }
}

class GroupFormSheet extends StatefulWidget {
  const GroupFormSheet({
    super.key,
    required this.title,
    required this.primaryActionLabel,
  });

  final String title;
  final String primaryActionLabel;

  @override
  State<GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends State<GroupFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = false;
  bool _requiresApproval = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _GroupFormResult(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isPublic: _isPublic,
        requiresApproval: _requiresApproval,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  prefixIcon: Icon(Icons.group),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a group name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
                title: const Text('Public group'),
                subtitle: const Text(
                  'Allow others to find your group in public listings.',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                value: _requiresApproval,
                onChanged: (value) => setState(() => _requiresApproval = value),
                title: const Text('Require approval to join'),
                subtitle: const Text(
                  'New members must be approved by an admin before joining.',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: Text(widget.primaryActionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JoinGroupSheet extends StatefulWidget {
  const JoinGroupSheet({super.key});

  @override
  State<JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<JoinGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _linkController = TextEditingController();
  int _joinMethod = 0; // 0 = code, 1 = link

  @override
  void dispose() {
    _codeController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_joinMethod == 0) {
      Navigator.of(context).pop(
        _JoinGroupResult(inviteCode: _codeController.text.trim().toUpperCase()),
      );
    } else {
      Navigator.of(
        context,
      ).pop(_JoinGroupLinkResult(link: _linkController.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join a group',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Invite Code')),
                  ButtonSegment(value: 1, label: Text('Link')),
                ],
                selected: {_joinMethod},
                onSelectionChanged: (Set<int> selected) {
                  setState(() {
                    _joinMethod = selected.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_joinMethod == 0)
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Invite code',
                    prefixIcon: Icon(Icons.qr_code),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter the invite code shared with you';
                    }
                    if (value.trim().length < 6) {
                      return 'Invite code must be 6 characters';
                    }
                    return null;
                  },
                )
              else
                TextFormField(
                  controller: _linkController,
                  decoration: const InputDecoration(
                    labelText: 'Group link',
                    helperText: 'Paste the shareable link or group ID',
                    prefixIcon: Icon(Icons.link),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter the group link';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _submit, child: const Text('Join group')),
            ],
          ),
        ),
      ),
    );
  }
}

class AssignmentFormSheet extends StatefulWidget {
  const AssignmentFormSheet({
    super.key,
    required this.group,
    required this.admin,
  });

  final Group group;
  final GroupMember admin;

  @override
  State<AssignmentFormSheet> createState() => _AssignmentFormSheetState();
}

class _AssignmentFormSheetState extends State<AssignmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _surahController = TextEditingController();
  final _rangeController = TextEditingController();
  final _juzController = TextEditingController(text: '1');
  String? _memberUid;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    _memberUid = widget.group.members.isEmpty
        ? null
        : widget.group.members.first.uid;
  }

  @override
  void dispose() {
    _surahController.dispose();
    _rangeController.dispose();
    _juzController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDate: _deadline ?? now,
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _memberUid == null) {
      return;
    }
    Navigator.of(context).pop(
      _AssignmentFormResult(
        memberUid: _memberUid!,
        surah: _surahController.text.trim().isEmpty 
            ? null 
            : _surahController.text.trim(),
        ayatRange: _rangeController.text.trim().isEmpty 
            ? null 
            : _rangeController.text.trim(),
        juzNumber: double.parse(_juzController.text.trim()),
        deadline: _deadline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assign recitation',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _memberUid,
                decoration: const InputDecoration(
                  labelText: 'Assign to',
                  prefixIcon: Icon(Icons.person_add_alt),
                ),
                items: widget.group.members
                    .map(
                      (member) => DropdownMenuItem(
                        value: member.uid,
                        child: Text(
                          member.name.isEmpty ? member.email : member.name,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _memberUid = value),
                validator: (value) => value == null ? 'Select a member' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _juzController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Juz number (1-30) *',
                  helperText: 'Required. Can be a decimal (e.g., 1.5, 2.3)',
                  prefixIcon: Icon(Icons.stacked_bar_chart),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Juz number is required';
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed < 1 || parsed > 30) {
                    return 'Enter a Juz number between 1 and 30';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _surahController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Surah name (optional)',
                  helperText: 'Optional - leave blank if not specifying a surah',
                  prefixIcon: Icon(Icons.menu_book),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rangeController,
                decoration: const InputDecoration(
                  labelText: 'Ayah range (optional, e.g. 1-20)',
                  helperText: 'Optional - leave blank if not specifying ayahs',
                  prefixIcon: Icon(Icons.format_list_numbered),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Deadline (optional)'),
                subtitle: Text(
                  _deadline == null
                      ? 'No deadline selected'
                      : DateFormat.yMMMMd().format(_deadline!),
                ),
                trailing: TextButton(
                  onPressed: _pickDeadline,
                  child: const Text('Select date'),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: const Text('Assign recitation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupFormResult {
  const _GroupFormResult({
    required this.name,
    this.description,
    required this.isPublic,
    this.requiresApproval = false,
  });

  final String name;
  final String? description;
  final bool isPublic;
  final bool requiresApproval;
}

class _JoinGroupResult {
  const _JoinGroupResult({required this.inviteCode});

  final String inviteCode;
}

class _JoinGroupLinkResult {
  const _JoinGroupLinkResult({required this.link});

  final String link;
}

class _AssignmentFormResult {
  const _AssignmentFormResult({
    required this.memberUid,
    this.surah,
    this.ayatRange,
    required this.juzNumber,
    this.deadline,
  });

  final String memberUid;
  final String? surah;
  final String? ayatRange;
  final double juzNumber;
  final DateTime? deadline;
}

class GroupMemberSearch extends StatefulWidget {
  const GroupMemberSearch({
    super.key,
    required this.group,
    required this.onUserSelected,
  });

  final Group group;
  final ValueChanged<AppUser> onUserSelected;

  @override
  State<GroupMemberSearch> createState() => _GroupMemberSearchState();
}

class _GroupMemberSearchState extends State<GroupMemberSearch> {
  final TextEditingController _controller = TextEditingController();
  List<AppUser> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {}); // Rebuild when text changes to update suffix icon
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final trimmed = value.trim();
      if (trimmed.length < 2) {
        if (mounted) {
          setState(() {
            _results = [];
            _isSearching = false;
          });
        }
        return;
      }

      setState(() {
        _isSearching = true;
      });

      try {
        final firestore = context.read<FirestoreService>();
        final users = await firestore.searchUsers(
          trimmed,
          excludeUserIds: widget.group.memberIds,
        );
        if (mounted) {
          setState(() {
            _results = users;
            _isSearching = false;
          });
        }
      } catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _results = [];
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.trim().length >= 2;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Search by name or email',
            hintText: 'Type at least 2 characters to search',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _results = [];
                        _isSearching = false;
                      });
                    },
                  )
                : null,
          ),
          onChanged: _onQueryChanged,
          autofocus: false,
        ),
        const SizedBox(height: 12),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (!hasQuery)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Type at least 2 characters to search for users by name or email.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'No users found. Try a different search term.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          ..._results.map(
            (user) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  ),
                ),
                title: Text(
                  user.name.isEmpty ? user.email : user.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                trailing: FilledButton.icon(
                  onPressed: () => widget.onUserSelected(user),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MySentRequestsSection extends StatelessWidget {
  const _MySentRequestsSection({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    return StreamBuilder<List<JoinRequest>>(
      stream: firestore.watchJoinRequests(userId: user.uid),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        final pendingRequests = requests
            .where((r) => r.status == 'pending')
            .toList();

        if (pendingRequests.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.pending_actions,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pending Join Requests',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Chip(
                      label: Text('${pendingRequests.length}'),
                      avatar: const Icon(Icons.hourglass_empty, size: 16),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...pendingRequests.map(
                  (request) => _SentRequestCard(request: request),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  const _SentRequestCard({required this.request});

  final JoinRequest request;

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    return StreamBuilder<Group?>(
      stream: firestore.watchGroup(request.groupId).handleError((_) => null),
      builder: (context, snapshot) {
        final group = snapshot.data;
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: group != null
                  ? Text(
                      group.name.isEmpty ? '?' : group.name[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Icon(Icons.group_outlined),
            ),
            title: Text(
              group?.name ?? 'Group',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Waiting for admin approval',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Requested ${_formatRequestDate(request.requestedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                      ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.pending,
                    size: 16,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pending',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatRequestDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}

class _JoinRequestsSection extends StatefulWidget {
  const _JoinRequestsSection({required this.group, required this.user});

  final Group group;
  final AppUser user;

  @override
  State<_JoinRequestsSection> createState() => _JoinRequestsSectionState();
}

class _JoinRequestsSectionState extends State<_JoinRequestsSection> {
  final Map<String, bool> _processingRequests = {};

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();
    return StreamBuilder<List<JoinRequest>>(
      stream: firestore.watchJoinRequests(groupId: widget.group.id),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        final pendingRequests = requests
            .where((r) => r.status == 'pending')
            .toList();

        if (pendingRequests.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Join Requests',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_add_alt,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${pendingRequests.length}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...pendingRequests.map(
              (request) => _PendingRequestCard(
                request: request,
                group: widget.group,
                admin: widget.user,
                isProcessing: _processingRequests[request.id] ?? false,
                onApprove: () => _handleApprove(request, firestore),
                onReject: () => _handleReject(request, firestore),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleApprove(JoinRequest request, FirestoreService firestore) async {
    setState(() {
      _processingRequests[request.id] = true;
    });

    try {
      final newUser = await firestore.fetchUser(request.userId);
      if (newUser != null) {
        await firestore.approveJoinRequest(
          request: request,
          reviewerUid: widget.user.uid,
          group: widget.group,
          newMember: newUser,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${request.userName} joined ${widget.group.name}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $error')),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingRequests[request.id] = false;
        });
      }
    }
  }

  Future<void> _handleReject(JoinRequest request, FirestoreService firestore) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Join Request'),
        content: Text(
          'Are you sure you want to reject ${request.userName}\'s request to join ${widget.group.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _processingRequests[request.id] = true;
    });

    try {
      await firestore.rejectJoinRequest(
        request: request,
        reviewerUid: widget.user.uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Request from ${request.userName} rejected',
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $error')),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingRequests[request.id] = false;
        });
      }
    }
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
    required this.request,
    required this.group,
    required this.admin,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final JoinRequest request;
  final Group group;
  final AppUser admin;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    request.userName.isEmpty
                        ? '?'
                        : request.userName[0].toUpperCase(),
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.userName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        request.userEmail,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isProcessing)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (request.message != null && request.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.message_outlined,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.message!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isProcessing ? null : onApprove,
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isProcessing ? null : onReject,
                    icon: const Icon(Icons.close, size: 20),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

