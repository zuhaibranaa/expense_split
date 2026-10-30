import { logger } from 'firebase-functions';
import {
  onDocumentCreated,
  onDocumentDeleted,
} from 'firebase-functions/v2/firestore';

import { db } from './lib/firestore';

/**
 * Mirrors `hasFcmToken` onto every member document linked to the user so the
 * "remind" button knows whether a push can reach them. Client-side collection
 * group writes are intentionally not allowed by the security rules.
 */
async function syncMemberPushFlag(
  uid: string,
  hasToken: boolean,
): Promise<void> {
  const memberships = await db
    .collectionGroup('members')
    .where('uid', '==', uid)
    .get();

  const chunkSize = 400;
  for (let index = 0; index < memberships.size; index += chunkSize) {
    const batch = db.batch();
    for (const doc of memberships.docs.slice(index, index + chunkSize)) {
      batch.update(doc.ref, { hasFcmToken: hasToken });
    }
    await batch.commit();
  }
}

export const onDeviceRegistered = onDocumentCreated(
  'users/{uid}/devices/{deviceId}',
  async (event) => {
    const { uid } = event.params;
    await syncMemberPushFlag(uid, true);
    logger.info(`Push enabled for ${uid}`);
  },
);

export const onDeviceRemoved = onDocumentDeleted(
  'users/{uid}/devices/{deviceId}',
  async (event) => {
    const { uid } = event.params;
    const remaining = await db
      .collection(`users/${uid}/devices`)
      .limit(1)
      .get();
    await syncMemberPushFlag(uid, !remaining.empty);
    logger.info(`Push flag recalculated for ${uid}`);
  },
);
