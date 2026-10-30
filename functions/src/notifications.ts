import { logger } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import {
  FieldValue,
  MemberDoc,
  assertMember,
  db,
  getDevicesForUids,
  getGroup,
  getUser,
  requireAuth,
  requireString,
} from './lib/firestore';
import { sendPushToDevices } from './lib/fcm';

function todayKey(): string {
  return new Date().toISOString().slice(0, 10).replace(/-/g, '');
}

export const sendSettlementReminder = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const toUid = requireString(request.data?.toUid, 'toUid');
  const groupId = requireString(request.data?.groupId, 'groupId');
  const groupName =
    typeof request.data?.groupName === 'string'
      ? request.data.groupName
      : 'your group';
  const amount =
    typeof request.data?.amount === 'number' ? request.data.amount : 0;
  const currencySymbol =
    typeof request.data?.currencySymbol === 'string'
      ? request.data.currencySymbol
      : '';

  if (uid === toUid) {
    throw new HttpsError(
      'invalid-argument',
      'You cannot send a reminder to yourself.',
    );
  }

  const group = await getGroup(groupId);
  assertMember(group, uid);
  assertMember(group, toUid);

  const members = await db
    .collection(`groups/${groupId}/members`)
    .where('uid', '==', toUid)
    .limit(1)
    .get();
  if (members.empty || (members.docs[0].data() as MemberDoc).isRemoved) {
    throw new HttpsError(
      'failed-precondition',
      'That person is no longer in this group.',
    );
  }

  const devices = await getDevicesForUids([toUid]);
  if (devices.length === 0) {
    throw new HttpsError(
      'failed-precondition',
      'They have not enabled notifications yet.',
    );
  }

  const sender = await getUser(uid);
  const reminderId = `${uid}_${toUid}_${todayKey()}`;

  try {
    await db.doc(`reminders/${reminderId}`).create({
      fromUid: uid,
      toUid,
      groupId,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    const code = (error as { code?: number }).code;
    // gRPC ALREADY_EXISTS
    if (code === 6) {
      throw new HttpsError(
        'resource-exhausted',
        'You already sent a reminder to this person today.',
      );
    }
    throw error;
  }

  const amountText = amount > 0
    ? `${currencySymbol}${amount.toFixed(2)}`
    : 'an outstanding balance';

  const sent = await sendPushToDevices(devices, {
    title: 'Settlement reminder',
    body: `${sender.name?.trim() || 'Someone'} reminded you about ${amountText} in ${groupName}`,
    data: {
      type: 'settlement_reminder',
      group_id: groupId,
      sender_id: uid,
      amount: amount.toString(),
      group_name: groupName,
    },
  });

  logger.info(`Settlement reminder ${reminderId} delivered to ${sent} devices`);
  return { sent };
});

export const sendTestNotification = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const targetUid =
    typeof request.data?.toUid === 'string' && request.data.toUid.length > 0
      ? request.data.toUid
      : uid;

  if (targetUid !== uid) {
    // Only allow sending a test push to yourself.
    throw new HttpsError(
      'permission-denied',
      'Test notifications can only be sent to your own devices.',
    );
  }

  const devices = await getDevicesForUids([uid]);
  if (devices.length === 0) {
    throw new HttpsError(
      'failed-precondition',
      'No push registration found for this device yet.',
    );
  }

  const sent = await sendPushToDevices(devices, {
    title: 'EquiSplit test notification',
    body: 'Push notifications are working on this device.',
    data: { type: 'test', sender_id: uid },
  });

  return { sent };
});
