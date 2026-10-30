import { logger } from 'firebase-functions';
import {
  onDocumentCreated,
  onDocumentUpdated,
} from 'firebase-functions/v2/firestore';

import {
  FieldValue,
  UserDoc,
  db,
  seedDefaultCategories,
} from './lib/firestore';

/**
 * Creates the personal group, its owner member document and the default
 * categories. Safe to run more than once: an existing personal group wins.
 */
export const bootstrapUser = onDocumentCreated(
  'users/{uid}',
  async (event) => {
    const uid = event.params.uid;
    const snapshot = event.data;
    if (!snapshot) return;

    const user = snapshot.data() as UserDoc;

    const groupRef = db.collection('groups').doc();
    const memberRef = groupRef.collection('members').doc(uid);

    const personalGroupId = await db.runTransaction(async (transaction) => {
      const freshUser = await transaction.get(snapshot.ref);
      const current = (freshUser.data() ?? user) as UserDoc;

      if (current.personalGroupId) {
        const existing = await transaction.get(
          db.doc(`groups/${current.personalGroupId}`),
        );
        if (existing.exists) return current.personalGroupId;
      }

      transaction.set(groupRef, {
        name: 'Personal',
        currency: current.defaultCurrency ?? 'USD',
        type: 'PERSONAL',
        ownerUid: uid,
        memberUids: [uid],
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        lastActivityAt: FieldValue.serverTimestamp(),
      });

      transaction.set(memberRef, {
        name: current.name?.trim() || current.email || 'Me',
        uid,
        isAdmin: true,
        isRemoved: false,
        email: current.email ?? null,
        avatarUrl: current.avatarUrl ?? null,
        hasFcmToken: false,
        createdAt: FieldValue.serverTimestamp(),
      });

      transaction.update(snapshot.ref, {
        personalGroupId: groupRef.id,
        updatedAt: FieldValue.serverTimestamp(),
      });

      return groupRef.id;
    });

    await seedDefaultCategories(personalGroupId);
    logger.info(`Bootstrapped personal group ${personalGroupId} for ${uid}`);
  },
);

/**
 * Propagates display-name and avatar edits onto every member document that is
 * linked to this user. Clients cannot write across groups, so this is the only
 * way to keep the denormalised copies fresh.
 */
export const syncMemberProfile = onDocumentUpdated(
  'users/{uid}',
  async (event) => {
    const { uid } = event.params;
    const before = event.data?.before.data() as UserDoc | undefined;
    const after = event.data?.after.data() as UserDoc | undefined;
    if (!before || !after) return;

    const nameChanged = before.name !== after.name;
    const avatarChanged = before.avatarUrl !== after.avatarUrl;
    if (!nameChanged && !avatarChanged) return;

    const memberships = await db
      .collectionGroup('members')
      .where('uid', '==', uid)
      .get();
    if (memberships.empty) return;

    const updates: Record<string, unknown> = {};
    if (nameChanged && after.name) updates.name = after.name.trim();
    if (avatarChanged) updates.avatarUrl = after.avatarUrl ?? null;

    const chunkSize = 400;
    for (let index = 0; index < memberships.size; index += chunkSize) {
      const batch = db.batch();
      for (const doc of memberships.docs.slice(index, index + chunkSize)) {
        batch.update(doc.ref, updates);
      }
      await batch.commit();
    }

    logger.info(`Synced member profile for ${uid}`);
  },
);
