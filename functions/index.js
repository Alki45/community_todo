const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const {Timestamp} = require('@google-cloud/firestore');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const buildSearchTokens = (name, email) => {
  const tokens = new Set();
  const addTokens = (value) => {
    const normalized = (value || '').trim().toLowerCase();
    if (!normalized) {
      return;
    }
    const parts = normalized.split(/\s+/);
    parts.forEach((part) => {
      for (let i = 1; i <= part.length; i += 1) {
        tokens.add(part.substring(0, i));
      }
    });
  };
  addTokens(name);
  addTokens(email);
  return Array.from(tokens);
};

const getUserDeviceTokens = async (uid) => {
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) {
    return [];
  }
  const data = userDoc.data();
  return Array.isArray(data.deviceTokens) ? data.deviceTokens : [];
};

exports.onRecitationCreated = functions.firestore
  .document('recitations/{recitationId}')
  .onCreate(async (snapshot) => {
    const recitation = snapshot.data();
    if (!recitation) {
      return null;
    }

    const tokens = await getUserDeviceTokens(recitation.assigned_to);
    const notification = {
      title: 'New recitation assigned',
      body: `${recitation.surah} (${recitation.ayat_range}) has been assigned to you.`,
    };

    const dataPayload = {
      groupId: recitation.group_id,
      assignmentId: snapshot.id,
      action: 'recitation_assigned',
    };

    const sends = [];

    if (tokens.length > 0) {
      sends.push(
        messaging.sendEachForMulticast({
          tokens,
          notification,
          data: dataPayload,
        }),
      );
    }

    sends.push(
      messaging.send({
        topic: `group_${recitation.group_id}`,
        notification: {
          title: 'Group update',
          body: `${recitation.assigned_to_name || 'A member'} received a new recitation.`,
        },
        data: dataPayload,
      }),
    );

    await Promise.allSettled(sends);
    functions.logger.info('Recitation assignment notifications dispatched.');
    return null;
  });

exports.onRecitationStatusUpdate = functions.firestore
  .document('recitations/{recitationId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    if (!before || !after) {
      return null;
    }

    if (before.status === after.status) {
      return null;
    }

    const notification = {
      title: 'Recitation progress update',
      body: `${after.assigned_to_name || 'A member'} marked ${after.surah} as ${after.status}.`,
    };

    const dataPayload = {
      groupId: after.group_id,
      assignmentId: change.after.id,
      action: 'recitation_status',
      status: after.status,
    };

    const sends = [
      messaging.send({
        topic: `group_${after.group_id}`,
        notification,
        data: dataPayload,
      }),
    ];

    if (after.status === 'completed') {
      const tokens = await getUserDeviceTokens(after.assigned_by);
      if (tokens.length > 0) {
        sends.push(
          messaging.sendEachForMulticast({
            tokens,
            notification: {
              title: 'Assignment completed',
              body: `${after.assigned_to_name || 'Your member'} completed ${after.surah}.`,
            },
            data: dataPayload,
          }),
        );
      }
    }

    await Promise.allSettled(sends);
    functions.logger.info('Recitation status notifications dispatched.');
    return null;
  });

exports.onAdminChange = functions.firestore
  .document('groups/{groupId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    if (!before || !after) {
      return null;
    }

    if (before.admin_uid === after.admin_uid) {
      return null;
    }

    const newAdminUid = after.admin_uid;
    const tokens = await getUserDeviceTokens(newAdminUid);

    const notification = {
      title: 'You are now the admin',
      body: `You have been assigned as the admin of ${after.name}.`,
    };

    const sends = [];
    if (tokens.length > 0) {
      sends.push(
        messaging.sendEachForMulticast({
          tokens,
          notification,
          data: {
            groupId: context.params.groupId,
            action: 'admin_assigned',
          },
        }),
      );
    }

    sends.push(
      messaging.send({
        topic: `group_${context.params.groupId}`,
        notification: {
          title: 'Admin update',
          body: `${after.name} has a new admin.`,
        },
        data: {
          groupId: context.params.groupId,
          action: 'admin_assigned',
        },
      }),
    );

    await Promise.allSettled(sends);
    functions.logger.info('Admin change notifications dispatched.');
    return null;
  });

exports.onJoinRequestCreated = functions.firestore
  .document('join_requests/{requestId}')
  .onCreate(async (snapshot, context) => {
    const request = snapshot.data();
    if (!request) {
      return null;
    }

    // Only notify for pending requests
    if (request.status !== 'pending') {
      return null;
    }

    // Fetch group details
    const groupDoc = await db.collection('groups').doc(request.group_id).get();
    if (!groupDoc.exists) {
      functions.logger.warn(`Group ${request.group_id} not found for join request`);
      return null;
    }

    const group = groupDoc.data();
    const adminUid = group.admin_uid;

    // Get admin device tokens
    const tokens = await getUserDeviceTokens(adminUid);

    const notification = {
      title: 'New join request',
      body: `${request.user_name || request.user_email} wants to join ${group.name}.`,
    };

    const dataPayload = {
      groupId: request.group_id,
      requestId: context.params.requestId,
      action: 'join_request_created',
      userId: request.user_id,
    };

    const sends = [];

    // Send notification to admin
    if (tokens.length > 0) {
      sends.push(
        messaging.sendEachForMulticast({
          tokens,
          notification,
          data: dataPayload,
        }),
      );
    }

    // Also send to group topic
    sends.push(
      messaging.send({
        topic: `group_${request.group_id}`,
        notification: {
          title: 'New join request',
          body: `${request.user_name || request.user_email} wants to join the group.`,
        },
        data: dataPayload,
      }),
    );

    await Promise.allSettled(sends);
    functions.logger.info('Join request notification dispatched.');
    return null;
  });

exports.onJoinRequestUpdated = functions.firestore
  .document('join_requests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (!before || !after) {
      return null;
    }

    // Only notify when status changes from pending to approved/rejected
    if (before.status !== 'pending' || after.status === 'pending') {
      return null;
    }

    const tokens = await getUserDeviceTokens(after.user_id);

    const isApproved = after.status === 'approved';
    const notification = {
      title: isApproved ? 'Join request approved' : 'Join request rejected',
      body: isApproved
        ? `Your request to join the group has been approved.`
        : `Your join request was rejected.`,
    };

    const dataPayload = {
      groupId: after.group_id,
      requestId: context.params.requestId,
      action: isApproved ? 'join_request_approved' : 'join_request_rejected',
      status: after.status,
    };

    if (tokens.length > 0) {
      await messaging.sendEachForMulticast({
        tokens,
        notification,
        data: dataPayload,
      });
      functions.logger.info(`Join request ${after.status} notification dispatched.`);
    }

    return null;
  });

const resolveSeedToken = () => {
  const fromConfig = functions.config().seed?.token;
  if (fromConfig) {
    return fromConfig;
  }
  return process.env.SEED_TOKEN;
};

exports.seedSampleData = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send({ error: 'Method not allowed' });
    return;
  }

  const requiredToken = resolveSeedToken();
  if (!requiredToken) {
    res
      .status(500)
      .send({ error: 'Seed token not configured. Set seed.token or SEED_TOKEN.' });
    return;
  }

  const providedToken = req.get('x-seed-token');
  if (providedToken !== requiredToken) {
    res.status(403).send({ error: 'Invalid seed token.' });
    return;
  }

  try {
    await runSeed();
    res.status(200).send({ status: 'ok' });
  } catch (error) {
    functions.logger.error('Seeding failed', error);
    res.status(500).send({ error: error.message });
  }
});

const runSeed = async () => {
  const now = new Date();
  const timestamp = Timestamp.fromDate(now);
  const defaultPassword = 'AstU2024!';

  const users = [
    {
      uid: 'user_aminah',
      name: 'Aminah Saleh',
      email: 'aliyunus0178@gmail.com',
      groups: ['astu_muslim_community'],
      activeGroupId: 'astu_muslim_community',
    },
    {
      uid: 'user_yusuf',
      name: 'Yusuf Hamdan',
      email: 'alikibret178@gmail.com',
      groups: ['astu_muslim_community'],
      activeGroupId: 'astu_muslim_community',
    },
    {
      uid: 'user_khadija',
      name: 'Khadija Rahman',
      email: 'khadijakibret2023@gmail.com',
      groups: ['astu_muslim_community'],
      activeGroupId: 'astu_muslim_community',
    },
    {
      uid: 'user_mohamed',
      name: 'Mohamed Idris',
      email: 'ibnyunusmuhammed@gmial.com',
      groups: ['astu_muslim_community'],
      activeGroupId: 'astu_muslim_community',
    },
    {
      uid: 'user_samira',
      name: 'Samira Bekele',
      email: 'alikibret45.com',
      groups: ['astu_muslim_community'],
      activeGroupId: 'astu_muslim_community',
    },
    {
      uid: 'user_najma',
      name: 'Najma Ali',
      email: 'bintkibret@gmail.com',
      groups: ['astu_muslim_community'],
      activeGroupId: 'astu_muslim_community',
    },
  ];

  const groupMembers = (groupId) => (userList) =>
    userList.map((uid, index) => {
      const profile = users.find((user) => user.uid === uid);
      return {
        uid,
        name: profile?.name ?? '',
        email: profile?.email ?? '',
      joined_at: Timestamp.fromDate(
          new Date(now.getTime() - (index + 1) * 3600 * 1000),
        ),
      };
    });

  const groups = [
    {
      id: 'astu_muslim_community',
      name: 'Astu Muslim Community',
      admin_uid: 'user_aminah',
      invite_code: 'ASTU24',
      is_public: true,
      description: 'Community recitation circle for Astu Muslims.',
      members: groupMembers('astu_muslim_community')([
        'user_aminah',
        'user_yusuf',
        'user_khadija',
        'user_mohamed',
        'user_samira',
        'user_najma',
      ]),
    },
  ];

  const recitations = [
    {
      id: 'recitation_khadija_5',
      group_id: 'astu_muslim_community',
      group_name: 'Astu Muslim Community',
      assigned_by: 'user_aminah',
      assigned_by_name: 'Aminah Saleh',
      assigned_to: 'user_khadija',
      assigned_to_name: 'Khadija Rahman',
      surah: "Al-Ma'idah",
      ayat_range: '1-26',
      juz_number: 6,
      status: 'ongoing',
      assigned_date: timestamp,
      deadline: Timestamp.fromDate(
        new Date(now.getTime() + 7 * 24 * 3600 * 1000),
      ),
    },
    {
      id: 'recitation_yusuf_15',
      group_id: 'astu_muslim_community',
      group_name: 'Astu Muslim Community',
      assigned_by: 'user_aminah',
      assigned_by_name: 'Aminah Saleh',
      assigned_to: 'user_yusuf',
      assigned_to_name: 'Yusuf Hamdan',
      surah: 'Al-Kahf',
      ayat_range: '1-50',
      juz_number: 15,
      status: 'pending',
      assigned_date: timestamp,
    },
    {
      id: 'recitation_mohamed_10',
      group_id: 'astu_muslim_community',
      group_name: 'Astu Muslim Community',
      assigned_by: 'user_aminah',
      assigned_by_name: 'Aminah Saleh',
      assigned_to: 'user_mohamed',
      assigned_to_name: 'Mohamed Idris',
      surah: 'Yunus',
      ayat_range: '1-30',
      juz_number: 11,
      status: 'ongoing',
      assigned_date: timestamp,
    },
    {
      id: 'recitation_samira_1',
      group_id: 'astu_muslim_community',
      group_name: 'Astu Muslim Community',
      assigned_by: 'user_aminah',
      assigned_by_name: 'Aminah Saleh',
      assigned_to: 'user_samira',
      assigned_to_name: 'Samira Bekele',
      surah: 'Al-Baqarah',
      ayat_range: '1-40',
      juz_number: 1,
      status: 'pending',
      assigned_date: timestamp,
    },
    {
      id: 'recitation_najma_30',
      group_id: 'astu_muslim_community',
      group_name: 'Astu Muslim Community',
      assigned_by: 'user_aminah',
      assigned_by_name: 'Aminah Saleh',
      assigned_to: 'user_najma',
      assigned_to_name: 'Najma Ali',
      surah: 'An-Naba',
      ayat_range: '1-40',
      juz_number: 30,
      status: 'pending',
      assigned_date: timestamp,
    },
  ];

  const announcements = [
    {
      group_id: 'astu_muslim_community',
      id: 'announcement_1',
      author_uid: 'user_aminah',
      author_name: 'Aminah Saleh',
      message:
        'Reminder: Let us recite Surah Al-Baqarah daily. The Prophet ﷺ said the Shaytan flees from a home where it is recited.',
      is_hadith: true,
      pinned: true,
      created_at: timestamp,
    },
    {
      group_id: 'astu_muslim_community',
      id: 'announcement_2',
      author_uid: 'user_yusuf',
      author_name: 'Yusuf Hamdan',
      message:
        'Great progress this week everyone! Please update your assignment status before Maghrib.',
      is_hadith: false,
      pinned: false,
      created_at: timestamp,
    },
  ];

  await seedAuthUsers(users, defaultPassword);
  await seedUsers(users, timestamp);
  await seedGroups(groups, timestamp);
  await seedRecitations(recitations);
  await seedAnnouncements(announcements);
};

const seedAuthUsers = async (users, password) => {
  await Promise.all(
    users.map(async (user) => {
      try {
        await admin.auth().getUser(user.uid);
      } catch (error) {
        if (error.code === 'auth/user-not-found') {
          await admin.auth().createUser({
            uid: user.uid,
            email: user.email,
            password,
            displayName: user.name,
            emailVerified: true,
          });
        } else {
          throw error;
        }
      }
    }),
  );
};

const seedUsers = async (users, timestamp) => {
  const batch = db.batch();
  users.forEach((user) => {
    const ref = db.collection('users').doc(user.uid);
    batch.set(ref, {
      uid: user.uid,
      name: user.name,
      email: user.email,
      groups: user.groups,
      deviceTokens: [],
      searchTokens: buildSearchTokens(user.name, user.email),
      name_lower: user.name.toLowerCase(),
      email_lower: user.email.toLowerCase(),
      created_at: timestamp,
      activeGroupId: user.activeGroupId,
    });
  });
  await batch.commit();
};

const seedGroups = async (groups, timestamp) => {
  const batch = db.batch();
  groups.forEach((group) => {
    const ref = db.collection('groups').doc(group.id);
    batch.set(ref, {
      name: group.name,
      admin_uid: group.admin_uid,
      invite_code: group.invite_code,
      is_public: group.is_public,
      description: group.description,
      created_at: timestamp,
      member_ids: group.members.map((member) => member.uid),
      members: group.members,
      admin_votes: {},
    });
  });
  await batch.commit();
};

const seedRecitations = async (recitations) => {
  const batch = db.batch();
  recitations.forEach((assignment) => {
    const ref = db.collection('recitations').doc(assignment.id);
    batch.set(ref, {
      ...assignment,
    });
  });
  await batch.commit();
};

const seedAnnouncements = async (items) => {
  const writes = items.map((item) => {
    const ref = db
      .collection('groups')
      .doc(item.group_id)
      .collection('announcements')
      .doc(item.id);
    return ref.set({
      group_id: item.group_id,
      author_uid: item.author_uid,
      author_name: item.author_name,
      message: item.message,
      is_hadith: item.is_hadith,
      pinned: item.pinned,
      created_at: item.created_at,
    });
  });
  await Promise.all(writes);
};
