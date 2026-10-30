import { randomBytes } from 'node:crypto';

import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineString } from 'firebase-functions/params';

import {
  FieldValue,
  GroupDoc,
  InviteDoc,
  MemberDoc,
  UserDoc,
  assertMember,
  db,
  deleteDocuments,
  getGroup,
  getUser,
  isGroupAdmin,
  requireAuth,
  requireString,
  seedDefaultCategories,
} from './lib/firestore';

const INVITE_BASE_URL = defineString('INVITE_BASE_URL', {
  default: 'https://equisplit-d4c74.web.app',
  description: 'Public origin used when building /join?token= invite links.',
});

const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

/** Seeds the nine default categories for every newly created group. */
export const onGroupCreated = onDocumentCreated(
  'groups/{groupId}',
  async (event) => {
    const { groupId } = event.params;
    const snapshot = await db.doc(`groups/${groupId}`).get();
    if (!snapshot.exists) return;

    await seedDefaultCategories(groupId);
  },
);

export const createInvite = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const groupId = requireString(request.data?.groupId, 'groupId');
  const memberId = requireString(request.data?.memberId, 'memberId');

  const group = await getGroup(groupId);
  assertMember(group, uid);

  const memberRef = db.doc(`groups/${groupId}/members/${memberId}`);
  const memberSnapshot = await memberRef.get();
  if (!memberSnapshot.exists) {
    throw new HttpsError('not-found', 'Member not found.');
  }

  const member = memberSnapshot.data() as MemberDoc;
  if (member.isRemoved === true) {
    throw new HttpsError(
      'failed-precondition',
      'That person was removed from the group.',
    );
  }
  if (member.uid) {
    throw new HttpsError(
      'failed-precondition',
      'That person already has an account linked to this group.',
    );
  }

  const token = randomBytes(32).toString('base64url');
  const expiresAt = new Date(Date.now() + INVITE_TTL_MS);

  await db.doc(`invites/${token}`).set({
    groupId,
    memberId,
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt,
    used: false,
  });

  const baseUrl = INVITE_BASE_URL.value().replace(/\/$/, '');
  return {
    token,
    url: `${baseUrl}/join?token=${encodeURIComponent(token)}`,
    expiresAt: expiresAt.getTime(),
  };
});

export const claimInvite = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const token = requireString(request.data?.token, 'token');

  return db.runTransaction(async (transaction) => {
    const inviteRef = db.doc(`invites/${token}`);
    const inviteSnapshot = await transaction.get(inviteRef);
    if (!inviteSnapshot.exists) {
      throw new HttpsError('not-found', 'This invite link is invalid.');
    }

    const invite = inviteSnapshot.data() as InviteDoc;
    if (invite.used === true) {
      throw new HttpsError(
        'already-exists',
        'This invite has already been used.',
      );
    }
    if (invite.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError(
        'deadline-exceeded',
        'This invite has expired. Ask for a new one.',
      );
    }

    const groupRef = db.doc(`groups/${invite.groupId}`);
    const groupSnapshot = await transaction.get(groupRef);
    if (!groupSnapshot.exists) {
      throw new HttpsError('not-found', 'This group no longer exists.');
    }

    const group = groupSnapshot.data() as GroupDoc;
    if ((group.memberUids ?? []).includes(uid)) {
      throw new HttpsError(
        'already-exists',
        'You are already a member of this group.',
      );
    }

    const memberRef = groupRef.collection('members').doc(invite.memberId);
    const memberSnapshot = await transaction.get(memberRef);
    if (!memberSnapshot.exists) {
      throw new HttpsError(
        'not-found',
        'This invitation is no longer valid.',
      );
    }

    const member = memberSnapshot.data() as MemberDoc;
    if (member.isRemoved === true) {
      throw new HttpsError(
        'failed-precondition',
        'This invitation is no longer valid.',
      );
    }
    if (member.uid && member.uid !== uid) {
      throw new HttpsError(
        'already-exists',
        'This invite has already been claimed.',
      );
    }

    const userSnapshot = await transaction.get(db.doc(`users/${uid}`));
    const user = userSnapshot.exists
      ? (userSnapshot.data() as UserDoc)
      : ({} as UserDoc);

    transaction.update(memberRef, {
      uid,
      name: user.name?.trim() || member.name || 'Member',
      email: user.email ?? member.email ?? null,
      avatarUrl: user.avatarUrl ?? member.avatarUrl ?? null,
      hasFcmToken: false,
    });

    transaction.update(groupRef, {
      memberUids: FieldValue.arrayUnion(uid),
      updatedAt: FieldValue.serverTimestamp(),
    });

    transaction.delete(inviteRef);

    return {
      groupId: invite.groupId,
      memberId: invite.memberId,
      groupName: group.name,
    };
  });
});

export const removeMember = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const groupId = requireString(request.data?.groupId, 'groupId');
  const memberId = requireString(request.data?.memberId, 'memberId');

  const group = await getGroup(groupId);
  assertMember(group, uid);

  const admin = await isGroupAdmin(groupId, group, uid);
  if (!admin) {
    throw new HttpsError(
      'permission-denied',
      'Only the group owner or an admin can remove members.',
    );
  }

  if (memberId === group.ownerUid || memberId === uid) {
    throw new HttpsError(
      'failed-precondition',
      'The group owner cannot be removed.',
    );
  }

  const memberRef = db.doc(`groups/${groupId}/members/${memberId}`);
  const memberSnapshot = await memberRef.get();
  if (!memberSnapshot.exists) {
    throw new HttpsError('not-found', 'Member not found.');
  }

  const member = memberSnapshot.data() as MemberDoc;
  if (member.uid && member.uid === group.ownerUid) {
    throw new HttpsError(
      'failed-precondition',
      'The group owner cannot be removed.',
    );
  }
  if (member.isRemoved === true) return { removed: false };

  const updates: Record<string, unknown> = {
    isRemoved: true,
    hasFcmToken: false,
  };
  if (member.uid) {
    updates.memberUids = FieldValue.arrayRemove(member.uid);
  }

  await memberRef.update({
    isRemoved: true,
    hasFcmToken: false,
  });
  await db.doc(`groups/${groupId}`).update({
    ...updates,
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { removed: true };
});

export const deleteGroup = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const groupId = requireString(request.data?.groupId, 'groupId');

  const group = await getGroup(groupId);
  if (group.ownerUid !== uid) {
    throw new HttpsError(
      'permission-denied',
      'Only the group owner can delete this group.',
    );
  }

  await db.recursiveDelete(db.doc(`groups/${groupId}`));
  logger.info(`Deleted group ${groupId} (owner ${uid})`);
  return { deleted: true };
});

/** Deletes the personal-group expenses and every cash inflow for the caller. */
export const resetPersonalBalance = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const user = await getUser(uid);

  let deletedExpenses = 0;
  let deletedInflows = 0;

  if (user.personalGroupId) {
    // `personalGroupId` is client-writable, so never trust it blindly. Only
    // delete when it still points at a PERSONAL group owned by this user.
    const personalGroupRef = db.doc(`groups/${user.personalGroupId}`);
    const personalGroupSnapshot = await personalGroupRef.get();
    const personalGroup = personalGroupSnapshot.data() as GroupDoc | undefined;

    if (
      personalGroupSnapshot.exists &&
      personalGroup?.type === 'PERSONAL' &&
      personalGroup.ownerUid === uid
    ) {
      const expenses = await personalGroupRef.collection('expenses').get();
      deletedExpenses = expenses.size;
      await deleteDocuments(expenses.docs.map((doc) => doc.ref));
    }
  }

  const inflows = await db
    .collection('cashInflows')
    .where('uid', '==', uid)
    .get();
  deletedInflows = inflows.size;
  await deleteDocuments(inflows.docs.map((doc) => doc.ref));

  return { deletedExpenses, deletedInflows };
});
