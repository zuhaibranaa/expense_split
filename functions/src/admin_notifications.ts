import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineString } from 'firebase-functions/params';

import { db, requireAuth, requireString } from './lib/firestore';
import {
  PushPayload,
  sendPushToDevices,
  sendPushToTopic,
  sendPushToUids,
} from './lib/fcm';
import { DeviceEntry } from './lib/firestore';

/**
 * Comma-separated uid list replacing Laravel's `users.is_admin` column
 * (D42). Default-deny: unset means nobody may call the admin senders.
 */
const adminUids = defineString('ADMIN_UIDS');

function requireAdmin(uid: string): void {
  const allowed = adminUids
    .value()
    .split(',')
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
  if (!allowed.includes(uid)) {
    throw new HttpsError('permission-denied', 'Admin access required.');
  }
}

/** Mirrors Laravel's validation: title <= 255, body <= 1000, optional data
 * map with FCM's string values requirement. */
function parseNotificationPayload(input: unknown): PushPayload {
  const data = (input ?? {}) as Record<string, unknown>;
  const title = requireString(data.title, 'title');
  const body = requireString(data.body, 'body');
  if (title.length > 255) {
    throw new HttpsError(
      'invalid-argument',
      'title must be at most 255 characters.',
    );
  }
  if (body.length > 1000) {
    throw new HttpsError(
      'invalid-argument',
      'body must be at most 1000 characters.',
    );
  }

  const payloadData: Record<string, string> = {};
  const raw = data.data;
  if (raw != null) {
    if (typeof raw !== 'object' || Array.isArray(raw)) {
      throw new HttpsError(
        'invalid-argument',
        'data must be a map with string values.',
      );
    }
    for (const [key, value] of Object.entries(
      raw as Record<string, unknown>,
    )) {
      payloadData[key] = value == null ? '' : String(value);
    }
  }
  return { title, body, data: payloadData };
}

/** All registered devices across users (Laravel's send-to-all). */
async function getAllDevices(): Promise<DeviceEntry[]> {
  const snapshot = await db.collectionGroup('devices').get();
  const seen = new Set<string>();
  const devices: DeviceEntry[] = [];
  for (const doc of snapshot.docs) {
    const data = doc.data() as { token?: string };
    if (!data.token || seen.has(data.token)) continue;
    seen.add(data.token);
    devices.push({ token: data.token, ref: doc.ref });
  }
  return devices;
}

/** Admin-only: send a push to one user's devices (Laravel `send-to-user`). */
export const sendNotificationToUser = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  requireAdmin(uid);
  const targetUid = requireString(request.data?.uid, 'uid');
  const payload = parseNotificationPayload(request.data);

  const sent = await sendPushToUids([targetUid], payload);
  if (sent === 0) {
    throw new HttpsError(
      'failed-precondition',
      'Target user did not grant notification permission.',
    );
  }
  return { sent };
});

/** Admin-only: send a push to every registered device (Laravel `send-to-all`). */
export const sendNotificationToAllUsers = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  requireAdmin(uid);
  const payload = parseNotificationPayload(request.data);

  const devices = await getAllDevices();
  if (devices.length === 0) {
    throw new HttpsError(
      'failed-precondition',
      'No users with notification permission found.',
    );
  }
  const sent = await sendPushToDevices(devices, payload);
  return { sent };
});

/** Admin-only: send a push to an FCM topic (Laravel `send-to-topic`). */
export const sendNotificationToTopic = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  requireAdmin(uid);
  const topic = requireString(request.data?.topic, 'topic');
  const payload = parseNotificationPayload(request.data);

  const messageId = await sendPushToTopic(topic, payload);
  return { messageId };
});
