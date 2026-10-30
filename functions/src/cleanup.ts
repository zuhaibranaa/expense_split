import { logger } from 'firebase-functions';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as functionsV1 from 'firebase-functions/v1';
import { DocumentReference } from 'firebase-admin/firestore';

import {
  FieldValue,
  Timestamp,
  db,
  deleteDocuments,
} from './lib/firestore';

/** Deletes expired and already-used invites once a day. */
export const cleanupInvites = onSchedule('every day 03:00', async () => {
  const now = Timestamp.now();
  const refs = new Map<string, DocumentReference>();

  const expired = await db
    .collection('invites')
    .where('expiresAt', '<', now)
    .get();
  const used = await db.collection('invites').where('used', '==', true).get();

  for (const doc of [...expired.docs, ...used.docs]) {
    refs.set(doc.ref.path, doc.ref);
  }

  await deleteDocuments([...refs.values()]);
  logger.info(`Deleted ${refs.size} invites`);
});

/**
 * Auth trigger (v1): remove the profile and devices, anonymise member
 * documents, and drop the uid from every group that referenced it.
 *
 * v1 triggers ignore `setGlobalOptions`, so the region is set explicitly to
 * keep the function next to Firestore.
 */
export const onUserDelete = functionsV1
  .region('europe-west1')
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;

    const userRef = db.doc(`users/${uid}`);
    const userSnapshot = await userRef.get();
    const personalGroupId = userSnapshot.exists
      ? (userSnapshot.data() as { personalGroupId?: string }).personalGroupId
      : undefined;

    if (personalGroupId) {
      await db.recursiveDelete(db.doc(`groups/${personalGroupId}`));
    }

    await db.recursiveDelete(userRef);

    const memberships = await db
      .collectionGroup('members')
      .where('uid', '==', uid)
      .get();

    const refs = memberships.docs.map((doc) => doc.ref);
    const chunkSize = 200;
    for (let index = 0; index < refs.length; index += chunkSize) {
      const batch = db.batch();
      for (const ref of refs.slice(index, index + chunkSize)) {
        batch.update(ref, {
          uid: null,
          name: 'Removed user',
          email: null,
          avatarUrl: null,
          hasFcmToken: false,
          isRemoved: true,
        });
        const groupRef = ref.parent.parent;
        if (groupRef) {
          batch.update(groupRef, {
            memberUids: FieldValue.arrayRemove(uid),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
    }

    logger.info(
      `Cleaned up deleted user ${uid} (${memberships.size} memberships)`,
    );
  });
