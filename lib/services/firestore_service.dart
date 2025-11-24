import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/app_announcement.dart';
import '../models/chat_message.dart';
import '../models/group_announcement.dart';
import '../models/group_model.dart';
import '../models/group_statistics.dart';
import '../models/join_request.dart';
import '../models/recitation_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  FirestoreService();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _db.collection('groups');
  CollectionReference<Map<String, dynamic>> get _recitationsRef =>
      _db.collection('recitations');
  CollectionReference<Map<String, dynamic>> get _announcementsRef =>
      _db.collection('announcements');
  CollectionReference<Map<String, dynamic>> get _joinRequestsRef =>
      _db.collection('join_requests');

  Future<AppUser?> fetchUser(String uid) async {
    final snapshot = await _usersRef.doc(uid).get();
    final data = snapshot.data();
    if (data == null) {
      return null;
    }
    return AppUser.fromMap(snapshot.id, data);
  }

  Stream<AppUser> watchUser(String uid) {
    return _usersRef.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) {
        throw StateError('User not found');
      }
      return AppUser.fromMap(snapshot.id, data);
    });
  }

  Future<List<AppUser>> searchUsers(
    String query, {
    List<String>? excludeUserIds,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return [];
    }

    final lowerQuery = trimmed.toLowerCase();
    final excluded = excludeUserIds?.toSet() ?? <String>{};
    final results = <AppUser>{};

    // Search by email (exact or partial)
    if (trimmed.contains('@')) {
      final emailSnapshot = await _usersRef
          .where('email_lower', isGreaterThanOrEqualTo: lowerQuery)
          .where('email_lower', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .limit(limit)
          .get();
      for (final doc in emailSnapshot.docs) {
        final user = AppUser.fromMap(doc.id, doc.data());
        if (!excluded.contains(user.uid)) {
          results.add(user);
        }
      }
    }

    // Search by username (if username field exists)
    if (trimmed.length >= 3 && !trimmed.contains(' ')) {
      try {
        final usernameSnapshot = await _usersRef
            .where('username_lower', isGreaterThanOrEqualTo: lowerQuery)
            .where('username_lower', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
            .limit(limit)
            .get();
        for (final doc in usernameSnapshot.docs) {
          final user = AppUser.fromMap(doc.id, doc.data());
          if (!excluded.contains(user.uid)) {
            results.add(user);
          }
        }
      } catch (_) {
        // Username search may fail if index doesn't exist, fall back to tokens
      }
    }

    // Search by name (using name_lower)
    try {
      final nameSnapshot = await _usersRef
          .where('name_lower', isGreaterThanOrEqualTo: lowerQuery)
          .where('name_lower', isLessThanOrEqualTo: '$lowerQuery\uf8ff')
          .limit(limit)
          .get();
      for (final doc in nameSnapshot.docs) {
        final user = AppUser.fromMap(doc.id, doc.data());
        if (!excluded.contains(user.uid)) {
          results.add(user);
        }
      }
    } catch (_) {
      // Name search may fail if index doesn't exist
    }

    // Fallback to search tokens if no results or as additional results
    if (results.length < limit) {
      final tokenSnapshot = await _usersRef
          .where('searchTokens', arrayContains: lowerQuery)
          .limit(limit)
          .get();
      for (final doc in tokenSnapshot.docs) {
        final user = AppUser.fromMap(doc.id, doc.data());
        if (!excluded.contains(user.uid)) {
          results.add(user);
        }
      }
    }

    // Filter results that match the query in email, username, or name
    final filtered = results.where((user) {
      final emailMatch = user.email.toLowerCase().contains(lowerQuery);
      final usernameMatch = (user.username ?? '').toLowerCase().contains(
        lowerQuery,
      );
      final nameMatch = user.name.toLowerCase().contains(lowerQuery);
      return emailMatch || usernameMatch || nameMatch;
    }).toList();

    // Sort by relevance (exact matches first, then partial)
    filtered.sort((a, b) {
      final aEmailExact = a.email.toLowerCase() == lowerQuery ? 1 : 0;
      final bEmailExact = b.email.toLowerCase() == lowerQuery ? 1 : 0;
      if (aEmailExact != bEmailExact) return bEmailExact - aEmailExact;

      final aUsernameExact = (a.username ?? '').toLowerCase() == lowerQuery
          ? 1
          : 0;
      final bUsernameExact = (b.username ?? '').toLowerCase() == lowerQuery
          ? 1
          : 0;
      if (aUsernameExact != bUsernameExact) {
        return bUsernameExact - aUsernameExact;
      }

      final aNameExact = a.name.toLowerCase() == lowerQuery ? 1 : 0;
      final bNameExact = b.name.toLowerCase() == lowerQuery ? 1 : 0;
      if (aNameExact != bNameExact) return bNameExact - aNameExact;

      return a.name.compareTo(b.name);
    });

    return filtered.take(limit).toList(growable: false);
  }

  Future<void> createUserRecord(AppUser user) async {
    final payload = user.toMap();
    payload['created_at'] = FieldValue.serverTimestamp();
    payload['searchTokens'] = _buildSearchTokens(
      name: user.name,
      email: user.email,
      username: user.username,
      country: user.country,
      city: user.city,
    );
    payload['name_lower'] = user.name.toLowerCase();
    payload['email_lower'] = user.email.toLowerCase();
    if ((user.username ?? '').isNotEmpty) {
      payload['username_lower'] = user.username!.toLowerCase();
    }
    await _usersRef.doc(user.uid).set(payload, SetOptions(merge: true));
  }

  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    var pendingUpdates = Map<String, dynamic>.from(updates);
    final shouldRefreshTokens = [
      'name',
      'email',
      'username',
      'country',
      'city',
    ].any(pendingUpdates.containsKey);

    if (shouldRefreshTokens) {
      final snapshot = await _usersRef.doc(uid).get();
      final current = snapshot.data() ?? {};
      final name = (pendingUpdates['name'] ?? current['name'] ?? '') as String;
      final email =
          (pendingUpdates['email'] ?? current['email'] ?? '') as String;
      final username =
          (pendingUpdates['username'] ?? current['username'] ?? '') as String;
      final country =
          (pendingUpdates['country'] ?? current['country'] ?? '') as String;
      final city = (pendingUpdates['city'] ?? current['city'] ?? '') as String;
      pendingUpdates = {
        ...pendingUpdates,
        'searchTokens': _buildSearchTokens(
          name: name,
          email: email,
          username: username,
          country: country,
          city: city,
        ),
        'name_lower': name.toLowerCase(),
        'email_lower': email.toLowerCase(),
        if (username.isNotEmpty) 'username_lower': username.toLowerCase(),
      };
    }
    await _usersRef.doc(uid).set(pendingUpdates, SetOptions(merge: true));
  }

  Future<void> saveDeviceToken(String uid, String token) async {
    await _usersRef.doc(uid).set({
      'deviceTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  Stream<List<Group>> watchUserGroups(String uid) {
    return _groupsRef
        .where('member_ids', arrayContains: uid)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(Group.fromDoc).toList(growable: false),
        );
  }

  Stream<Group> watchGroup(String groupId) {
    return _groupsRef.doc(groupId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw StateError('Group not found');
      }
      return Group.fromDoc(snapshot);
    });
  }

  Future<Group> createGroup({
    required String name,
    required AppUser creator,
    String? description,
    bool isPublic = false,
    bool requiresApproval = false,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Group name cannot be empty');
    }

    final docRef = _groupsRef.doc();
    final inviteCode = _generateInviteCode();
    final now = DateTime.now();
    // Generate shareable link - format: qurantodo://group/{groupId}
    final shareableLink = 'qurantodo://group/${docRef.id}';

    final members = [
      GroupMember(
        uid: creator.uid,
        name: creator.name,
        email: creator.email,
        joinedAt: now,
        status: 'active',
        lastActiveAt: now,
      ),
    ];

    final group = Group(
      id: docRef.id,
      name: name.trim(),
      adminUid: creator.uid,
      members: members,
      memberIds: members.map((member) => member.uid).toList(),
      inviteCode: inviteCode,
      shareableLink: shareableLink,
      createdAt: now,
      isPublic: isPublic,
      requiresApproval: requiresApproval,
      description: description?.trim(),
    );

    try {
      await _db.runTransaction((transaction) async {
        transaction.set(docRef, group.toMap());
        transaction.set(_usersRef.doc(creator.uid), {
          'groups': FieldValue.arrayUnion([docRef.id]),
        }, SetOptions(merge: true));
      });

      // Verify the group was created
      final createdDoc = await docRef.get();
      if (!createdDoc.exists) {
        throw StateError('Failed to create group: document not found after creation');
      }

      return group;
    } catch (e) {
      // If transaction fails, try to clean up
      try {
        await docRef.delete();
      } catch (_) {
        // Ignore cleanup errors
      }
      rethrow;
    }
  }

  Future<Group?> findGroupByLink(String link) async {
    // Extract group ID from link (format: qurantodo://group/{groupId})
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'qurantodo') {
      return null;
    }

    if (uri.host == 'group' && uri.pathSegments.isNotEmpty) {
      final groupId = uri.pathSegments.first;
      final doc = await _groupsRef.doc(groupId).get();
      if (doc.exists) {
        return Group.fromDoc(doc);
      }
    }

    // Also try direct group ID
    final doc = await _groupsRef.doc(link).get();
    if (doc.exists) {
      return Group.fromDoc(doc);
    }

    return null;
  }

  Future<Group> joinGroupByCode({
    required AppUser user,
    required String inviteCode,
  }) async {
    final query = await _groupsRef
        .where('invite_code', isEqualTo: inviteCode.trim().toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw StateError('Invalid invite code');
    }

    final groupDoc = query.docs.first;
    final group = Group.fromDoc(groupDoc);

    if (group.memberIds.contains(user.uid)) {
      return group;
    }

    // If group requires approval, create a join request instead
    if (group.requiresApproval && group.adminUid != user.uid) {
      await createJoinRequest(group: group, user: user);
      throw StateError('Join request sent. Waiting for admin approval.');
    }

    final member = GroupMember(
      uid: user.uid,
      name: user.name,
      email: user.email,
      joinedAt: DateTime.now(),
      status: 'active',
      lastActiveAt: DateTime.now(),
    );

    await _db.runTransaction((transaction) async {
      final ref = _groupsRef.doc(group.id);
      transaction.update(ref, {
        'members': FieldValue.arrayUnion([member.toMap()]),
        'member_ids': FieldValue.arrayUnion([user.uid]),
        'admin_votes.$user.uid': FieldValue.arrayRemove([user.uid]),
      });
      transaction.set(_usersRef.doc(user.uid), {
        'groups': FieldValue.arrayUnion([group.id]),
      }, SetOptions(merge: true));
    });

    final refreshed = group.copyWith(
      members: [...group.members, member],
      memberIds: [...group.memberIds, user.uid],
    );
    return refreshed;
  }

  Future<void> leaveGroup({required AppUser user, required Group group}) async {
    // If admin is leaving and there are other members, they must assign a new admin first
    if (group.adminUid == user.uid && group.memberCount > 1) {
      throw StateError('Admin must assign a new admin before leaving.');
    }

    await _db.runTransaction((transaction) async {
      final ref = _groupsRef.doc(group.id);
      final updatedMembers = group.members
          .where((member) => member.uid != user.uid)
          .map((member) => member.toMap())
          .toList();
      
      // If admin is leaving and they're the only member, delete the group
      if (group.adminUid == user.uid && group.memberCount == 1) {
        transaction.delete(ref);
      } else {
        transaction.update(ref, {
          'members': updatedMembers,
          'member_ids': FieldValue.arrayRemove([user.uid]),
          'admin_votes.$user.uid': FieldValue.delete(),
        });
      }

      // Remove group from user's groups list
      // Note: Recitations are NOT deleted - they remain in history
      transaction.set(_usersRef.doc(user.uid), {
        'groups': FieldValue.arrayRemove([group.id]),
      }, SetOptions(merge: true));
    });
  }

  Future<void> removeMemberFromGroup({
    required Group group,
    required String memberUid,
    required String adminUid,
  }) async {
    if (group.adminUid != adminUid) {
      throw StateError('Only group admin can remove members');
    }

    if (memberUid == adminUid) {
      throw StateError('Admin cannot remove themselves. Use leave group instead.');
    }

    if (!group.memberIds.contains(memberUid)) {
      throw StateError('Member not found in group');
    }

    await _db.runTransaction((transaction) async {
      final ref = _groupsRef.doc(group.id);
      final updatedMembers = group.members
          .where((member) => member.uid != memberUid)
          .map((member) => member.toMap())
          .toList();
      
      transaction.update(ref, {
        'members': updatedMembers,
        'member_ids': FieldValue.arrayRemove([memberUid]),
        'admin_votes.$memberUid': FieldValue.delete(),
      });

      // Remove group from user's groups list
      // Note: Recitations are NOT deleted - they remain in history
      transaction.set(_usersRef.doc(memberUid), {
        'groups': FieldValue.arrayRemove([group.id]),
      }, SetOptions(merge: true));
    });
  }

  Future<void> deleteGroup({
    required Group group,
    required String adminUid,
  }) async {
    if (group.adminUid != adminUid) {
      throw StateError('Only group admin can delete the group');
    }

    await _db.runTransaction((transaction) async {
      // Remove group from all members' groups list
      for (final memberId in group.memberIds) {
        transaction.set(_usersRef.doc(memberId), {
          'groups': FieldValue.arrayRemove([group.id]),
        }, SetOptions(merge: true));
      }

      // Delete the group document
      // Note: Recitations are NOT deleted - they remain in history for tracking
      transaction.delete(_groupsRef.doc(group.id));
    });
  }

  Future<void> setAdmin({
    required String groupId,
    required String adminUid,
  }) async {
    await _groupsRef.doc(groupId).update({
      'admin_uid': adminUid,
      'admin_votes': {},
    });

    if (!kIsWeb) {
      await _messaging.subscribeToTopic('group_$groupId');
    }
  }

  Future<Group> addMemberToGroup({
    required Group group,
    required AppUser member,
  }) async {
    if (group.memberIds.contains(member.uid)) {
      // Return the current group if member already exists
      return group;
    }

    final newMember = GroupMember(
      uid: member.uid,
      name: member.name,
      email: member.email,
      joinedAt: DateTime.now(),
      status: 'active',
      lastActiveAt: DateTime.now(),
    );

    try {
      await _db.runTransaction((transaction) async {
        final docRef = _groupsRef.doc(group.id);
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw StateError('Group not found');
        }

        final data = snapshot.data();
        if (data == null) {
          throw StateError('Group data is null');
        }

        final current = Group.fromDoc(snapshot);
        if (current.memberIds.contains(member.uid)) {
          // Member already in group, return early
          return;
        }

        final updatedMembers = current.members
            .map((m) => m.toMap())
            .toList(growable: true);
        updatedMembers.add(newMember.toMap());

        transaction.update(docRef, {
          'members': updatedMembers,
          'member_ids': FieldValue.arrayUnion([member.uid]),
          'admin_votes.${member.uid}': FieldValue.delete(),
        });

        transaction.set(_usersRef.doc(member.uid), {
          'groups': FieldValue.arrayUnion([group.id]),
        }, SetOptions(merge: true));
      });

      // Fetch and return the updated group
      final updated = await _groupsRef.doc(group.id).get();
      if (!updated.exists) {
        throw StateError('Group not found after adding member');
      }
      return Group.fromDoc(updated);
    } catch (e) {
      throw StateError('Failed to add member to group: $e');
    }
  }

  Future<void> voteForAdmin({
    required Group group,
    required String candidateUid,
    required String voterUid,
  }) async {
    final candidateVotes =
        group.adminVotes[candidateUid]?.toSet() ?? <String>{};
    candidateVotes.add(voterUid);

    final votePayload = {'admin_votes.$candidateUid': candidateVotes.toList()};

    await _groupsRef.doc(group.id).update(votePayload);

    final majority = (group.memberCount / 2).ceil();
    if (candidateVotes.length >= majority) {
      await setAdmin(groupId: group.id, adminUid: candidateUid);
    }
  }

  Stream<List<RecitationAssignment>> watchMemberAssignments(
    String uid, {
    String? groupId,
  }) {
    Query<Map<String, dynamic>> query = _recitationsRef
        .where('assigned_to', isEqualTo: uid);

    // Always sort in memory to avoid index requirements
    if (groupId != null) {
      query = query.where('group_id', isEqualTo: groupId);
    }
    
    // Get all assignments and sort in memory to avoid Firestore index requirement
    return query.snapshots().map(
      (snapshot) {
        final assignments = snapshot.docs
            .map(RecitationAssignment.fromDoc)
            .toList(growable: false);
        // Sort by assigned_date descending (most recent first)
        assignments.sort((a, b) => b.assignedDate.compareTo(a.assignedDate));
        return assignments;
      },
    );
  }

  Stream<List<RecitationAssignment>> watchGroupAssignments(String groupId) {
    return _recitationsRef
        .where('group_id', isEqualTo: groupId)
        .orderBy('assigned_date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RecitationAssignment.fromDoc)
              .toList(growable: false),
        );
  }

  Future<RecitationAssignment> assignRecitation({
    required Group group,
    required GroupMember assignedTo,
    required GroupMember assignedBy,
    String? surah,
    String? ayatRange,
    required double juzNumber,
    DateTime? deadline,
  }) async {
    final docRef = _recitationsRef.doc();
    final now = DateTime.now();

    final assignment = RecitationAssignment(
      id: docRef.id,
      groupId: group.id,
      groupName: group.name,
      assignedBy: assignedBy.uid,
      assignedByName: assignedBy.name,
      assignedTo: assignedTo.uid,
      assignedToName: assignedTo.name,
      juzNumber: juzNumber,
      surah: surah?.trim().isEmpty == true ? null : surah?.trim(),
      ayatRange: ayatRange?.trim().isEmpty == true ? null : ayatRange?.trim(),
      status: 'pending',
      assignedDate: now,
      deadline: deadline,
    );

    await docRef.set(assignment.toMap());

    if (!kIsWeb) {
      await _messaging.subscribeToTopic('group_${group.id}');
    }

    return assignment;
  }

  Future<void> updateRecitationStatus({
    required RecitationAssignment assignment,
    required String status,
  }) async {
    await _recitationsRef.doc(assignment.id).update({
      'status': status,
      'completed_date': status == 'completed'
          ? FieldValue.serverTimestamp()
          : FieldValue.delete(),
    });

    if (status == 'completed' && !kIsWeb) {
      await _messaging.subscribeToTopic('group_${assignment.groupId}');
    }
  }

  Stream<List<RecitationAssignment>> watchWeekAssignments({
    required String groupId,
    required String weekId,
  }) {
    return _recitationsRef
        .where('group_id', isEqualTo: groupId)
        .where('week_id', isEqualTo: weekId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RecitationAssignment.fromDoc)
              .toList(growable: false),
        );
  }

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

  Stream<GroupStatistics> watchGroupStatistics(Group group) {
    return watchGroupAssignments(group.id).map((assignments) {
      final completed = assignments
          .where((assignment) => assignment.isCompleted)
          .length;
      final pending = assignments.length - completed;

      // Calculate juz-based progress (out of 30 juz)
      final completedJuz = <double>{};
      final totalJuz = <double>{};
      
      for (final assignment in assignments) {
        final juz = assignment.juzNumber;
        totalJuz.add(juz);
        if (assignment.isCompleted) {
          completedJuz.add(juz);
        }
      }
      
      // Calculate unique juz completed (1-30)
      final uniqueCompletedJuz = completedJuz.length;
      final uniqueTotalJuz = totalJuz.length;
      final juzProgress = uniqueTotalJuz > 0 
          ? uniqueCompletedJuz / 30.0 
          : 0.0; // Progress out of 30 juz

      final progressByMember = <String, MemberProgressBuilder>{};
      for (final member in group.members) {
        progressByMember[member.uid] = MemberProgressBuilder(member.name);
      }

      for (final assignment in assignments) {
        final builder =
            progressByMember[assignment.assignedTo] ??
            MemberProgressBuilder(assignment.assignedToName);
        if (assignment.isCompleted) {
          builder.completed++;
          builder.completedJuz.add(assignment.juzNumber);
        } else {
          builder.pending++;
        }
        builder.totalJuz.add(assignment.juzNumber);
        progressByMember[assignment.assignedTo] = builder;
      }

      final memberProgress = progressByMember.entries
          .map(
            (entry) {
              final builder = entry.value;
              final uniqueJuzCompleted = builder.completedJuz.length;
              final uniqueJuzTotal = builder.totalJuz.length;
              return MemberProgress(
                uid: entry.key,
                name: builder.name,
                completed: builder.completed,
                pending: builder.pending,
                juzCompleted: uniqueJuzCompleted,
                juzTotal: uniqueJuzTotal,
                juzProgress: uniqueJuzTotal > 0 
                    ? uniqueJuzCompleted / 30.0 
                    : 0.0,
              );
            },
          )
          .toList();

      memberProgress.sort(
        (a, b) => b.completionRate.compareTo(a.completionRate),
      );

      return GroupStatistics(
        groupId: group.id,
        totalAssignments: assignments.length,
        completedAssignments: completed,
        pendingAssignments: pending,
        membersProgress: memberProgress,
        juzCompleted: uniqueCompletedJuz,
        juzProgress: juzProgress,
      );
    });
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  List<String> _buildSearchTokens({
    required String name,
    required String email,
    String? username,
    String? country,
    String? city,
  }) {
    final tokens = <String>{};

    void addTokens(String value) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) {
        return;
      }
      final parts = normalized.split(RegExp(r'\s+'));
      for (final part in parts) {
        for (var i = 1; i <= part.length; i++) {
          tokens.add(part.substring(0, i));
        }
      }
    }

    addTokens(name);
    addTokens(email);
    if (username != null) {
      addTokens(username);
    }
    if (country != null) {
      addTokens(country);
    }
    if (city != null) {
      addTokens(city);
    }

    return tokens.toList(growable: false);
  }

  Stream<List<GroupAnnouncement>> watchAnnouncements(String groupId) {
    return _groupsRef
        .doc(groupId)
        .collection('announcements')
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) {
            final announcements = snapshot.docs
                .map(GroupAnnouncement.fromDoc)
                .toList(growable: false);
            // Sort by pinned first, then by created_at descending
            announcements.sort((a, b) {
              if (a.pinned != b.pinned) {
                return b.pinned ? 1 : -1; // Pinned items first
              }
              return b.createdAt.compareTo(a.createdAt);
            });
            return announcements;
          },
        );
  }

  Future<void> postAnnouncement({
    required Group group,
    required AppUser author,
    required String message,
    bool isHadith = false,
    bool pinned = false,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final collection = _groupsRef.doc(group.id).collection('announcements');
    await collection.add({
      'group_id': group.id,
      'author_uid': author.uid,
      'author_name': author.name.isEmpty ? author.email : author.name,
      'message': message.trim(),
      'created_at': FieldValue.serverTimestamp(),
      'is_hadith': isHadith,
      'pinned': pinned,
      'attachments': attachments ?? [],
    });
  }

  /// Send a chat message to a group
  Future<void> sendChatMessage({
    required Group group,
    required AppUser sender,
    required String message,
    List<Map<String, dynamic>>? attachments,
  }) async {
    final collection = _groupsRef.doc(group.id).collection('messages');
    await collection.add({
      'group_id': group.id,
      'sender_uid': sender.uid,
      'sender_name': sender.name.isEmpty ? sender.email : sender.name,
      'message': message.trim(),
      'created_at': FieldValue.serverTimestamp(),
      'attachments': attachments ?? [],
    });
  }

  /// Watch chat messages for a group (real-time updates)
  Stream<List<ChatMessage>> watchGroupMessages(String groupId) {
    return _groupsRef
        .doc(groupId)
        .collection('messages')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromDoc(doc))
            .toList());
  }

  Stream<List<AppAnnouncement>> watchCommunityAnnouncements({int limit = 10}) {
    return _announcementsRef
        .orderBy('published_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(AppAnnouncement.fromDoc)
              .toList(growable: false),
        );
  }

  // Join request methods
  Future<void> createJoinRequest({
    required Group group,
    required AppUser user,
    String? message,
  }) async {
    final requestRef = _joinRequestsRef.doc();
    final existingRequest = await _joinRequestsRef
        .where('group_id', isEqualTo: group.id)
        .where('user_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingRequest.docs.isNotEmpty) {
      throw StateError(
        'You already have a pending join request for this group',
      );
    }

    await requestRef.set({
      'group_id': group.id,
      'user_id': user.uid,
      'user_name': user.name.isEmpty ? user.email : user.name,
      'user_email': user.email,
      'requested_at': FieldValue.serverTimestamp(),
      'status': 'pending',
      if (message != null) 'message': message,
    });
  }

  Stream<List<JoinRequest>> watchJoinRequests({
    String? groupId,
    String? userId,
  }) {
    Query<Map<String, dynamic>> query = _joinRequestsRef;

    if (groupId != null) {
      query = query.where('group_id', isEqualTo: groupId);
    }
    if (userId != null) {
      query = query.where('user_id', isEqualTo: userId);
    }

    // Sort in memory to avoid Firestore index requirements
    return query.snapshots().map(
      (snapshot) {
        final requests = snapshot.docs
            .map(JoinRequest.fromDoc)
            .toList(growable: false);
        // Sort by requested_at descending (most recent first)
        requests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        return requests;
      },
    );
  }

  Future<void> approveJoinRequest({
    required JoinRequest request,
    required String reviewerUid,
    required Group group,
    required AppUser newMember,
  }) async {
    await _db.runTransaction((transaction) async {
      // Update request status
      transaction.update(_joinRequestsRef.doc(request.id), {
        'status': 'approved',
        'reviewed_by': reviewerUid,
        'reviewed_at': FieldValue.serverTimestamp(),
      });

      // Add member to group
      final member = GroupMember(
        uid: newMember.uid,
        name: newMember.name,
        email: newMember.email,
        joinedAt: DateTime.now(),
        status: 'active',
        lastActiveAt: DateTime.now(),
      );

      transaction.update(_groupsRef.doc(group.id), {
        'members': FieldValue.arrayUnion([member.toMap()]),
        'member_ids': FieldValue.arrayUnion([newMember.uid]),
        'admin_votes.${newMember.uid}': FieldValue.delete(),
      });

      // Update user's groups list
      transaction.set(_usersRef.doc(newMember.uid), {
        'groups': FieldValue.arrayUnion([group.id]),
      }, SetOptions(merge: true));
    });
  }

  Future<void> rejectJoinRequest({
    required JoinRequest request,
    required String reviewerUid,
  }) async {
    await _joinRequestsRef.doc(request.id).update({
      'status': 'rejected',
      'reviewed_by': reviewerUid,
      'reviewed_at': FieldValue.serverTimestamp(),
    });
  }

  // Member status update methods
  Future<void> updateMemberStatus({
    required String groupId,
    required String memberUid,
    required String status, // 'active', 'away', 'busy', 'offline'
  }) async {
    final groupDoc = await _groupsRef.doc(groupId).get();
    if (!groupDoc.exists) {
      throw StateError('Group not found');
    }

    final group = Group.fromDoc(groupDoc);
    final memberIndex = group.members.indexWhere((m) => m.uid == memberUid);
    if (memberIndex == -1) {
      throw StateError('Member not found in group');
    }

    final updatedMember = group.members[memberIndex].copyWith(
      status: status,
      lastActiveAt: DateTime.now(),
    );

    final updatedMembers = List<GroupMember>.from(group.members);
    updatedMembers[memberIndex] = updatedMember;

    await _groupsRef.doc(groupId).update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
    });
  }

  Future<Group> joinGroupByLink({
    required AppUser user,
    required String link,
  }) async {
    final group = await findGroupByLink(link);
    if (group == null) {
      throw StateError('Group not found or invalid link');
    }

    if (group.memberIds.contains(user.uid)) {
      return group;
    }

    // If group requires approval, create a join request instead
    if (group.requiresApproval && group.adminUid != user.uid) {
      await createJoinRequest(group: group, user: user);
      throw StateError('Join request sent. Waiting for admin approval.');
    }

    // Direct join if no approval required
    final member = GroupMember(
      uid: user.uid,
      name: user.name,
      email: user.email,
      joinedAt: DateTime.now(),
      status: 'active',
      lastActiveAt: DateTime.now(),
    );

    await _db.runTransaction((transaction) async {
      final ref = _groupsRef.doc(group.id);
      transaction.update(ref, {
        'members': FieldValue.arrayUnion([member.toMap()]),
        'member_ids': FieldValue.arrayUnion([user.uid]),
        'admin_votes.$user.uid': FieldValue.arrayRemove([user.uid]),
      });
      transaction.set(_usersRef.doc(user.uid), {
        'groups': FieldValue.arrayUnion([group.id]),
      }, SetOptions(merge: true));
    });

    final refreshed = group.copyWith(
      members: [...group.members, member],
      memberIds: [...group.memberIds, user.uid],
    );
    return refreshed;
  }
}

class MemberProgressBuilder {
  MemberProgressBuilder(this.name);

  final String name;
  int completed = 0;
  int pending = 0;
  final Set<double> completedJuz = <double>{};
  final Set<double> totalJuz = <double>{};
}
