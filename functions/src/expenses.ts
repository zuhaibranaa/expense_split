import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

import { ExpenseDoc, FieldValue, GroupDoc, db } from './lib/firestore';
import { sendPushToUids } from './lib/fcm';

export const onExpenseCreated = onDocumentCreated(
  'groups/{groupId}/expenses/{expenseId}',
  async (event) => {
    const { groupId, expenseId } = event.params;
    const snapshot = event.data;
    if (!snapshot) return;

    const expense = snapshot.data() as ExpenseDoc;

    const groupRef = db.doc(`groups/${groupId}`);
    const groupSnapshot = await groupRef.get();
    if (!groupSnapshot.exists) return;

    const group = groupSnapshot.data() as GroupDoc;
    await groupRef.update({
      lastActivityAt: FieldValue.serverTimestamp(),
    });

    const senderUid = expense.createdBy;
    const recipients = (group.memberUids ?? []).filter(
      (uid) => uid && uid !== senderUid,
    );
    if (recipients.length === 0) return;

    const isSettlement = expense.isSettlement === true;
    const payerName = expense.payerName?.trim() || 'Someone';
    const description = expense.description?.trim() || 'an expense';

    const title = isSettlement ? 'Payment recorded' : 'New expense';
    const body = isSettlement
      ? `${payerName} recorded a payment in ${group.name}`
      : `${payerName} added "${description}" in ${group.name}`;

    try {
      const sent = await sendPushToUids(recipients, {
        title,
        body,
        data: {
          type: isSettlement ? 'settlement' : 'expense_added',
          group_id: groupId,
          expense_id: expenseId,
          sender_id: senderUid ?? '',
          amount: String(expense.amount ?? ''),
          group_name: group.name ?? '',
          description: expense.description ?? '',
        },
      });
      logger.info(`Sent ${sent} expense notifications for ${expenseId}`);
    } catch (error) {
      logger.error('Failed to send expense notifications', error);
    }
  },
);
