import { logger } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { JWT } from 'google-auth-library';

import { FieldValue, Timestamp, db, requireAuth, requireString } from './lib/firestore';

/** Service-account JSON (Secret Manager) with Play Developer API access. */
const playServiceAccount = defineSecret('PLAY_SERVICE_ACCOUNT');

const PACKAGE_NAME = 'apk.equisplit.click';
const PLAY_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

interface PlayLineItem {
  expiryTime?: string;
  productId?: string;
}

interface PlaySubscriptionPurchase {
  subscriptionState?: string;
  lineItems?: PlayLineItem[];
}

/**
 * States that keep the user entitled: active, cancelled-but-not-expired,
 * and grace period. Everything else (on hold, paused, expired, pending)
 * ends premium (D41).
 */
const ENTITLED_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_CANCELED',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
]);

interface ServiceAccountCredentials {
  client_email?: string;
  private_key?: string;
}

/**
 * Verifies a Google Play subscription purchase with the Play Developer API
 * and grants premium until the subscription's expiry (D41). Clients call
 * this after a purchase and on startup restore. Idempotent; expired or
 * non-entitled subscriptions clear premium.
 */
export const verifyPremiumPurchase = onCall(
  { secrets: [playServiceAccount] },
  async (request) => {
    const uid = requireAuth(request.auth?.uid);
    const productId = requireString(request.data?.productId, 'productId');
    const purchaseToken = requireString(
      request.data?.purchaseToken,
      'purchaseToken',
    );

    const rawCredentials = playServiceAccount.value();
    if (!rawCredentials) {
      throw new HttpsError(
        'failed-precondition',
        'PLAY_SERVICE_ACCOUNT is not configured.',
      );
    }
    let credentials: ServiceAccountCredentials;
    try {
      credentials = JSON.parse(rawCredentials) as ServiceAccountCredentials;
    } catch {
      throw new HttpsError(
        'failed-precondition',
        'PLAY_SERVICE_ACCOUNT is not valid service-account JSON.',
      );
    }
    if (!credentials.client_email || !credentials.private_key) {
      throw new HttpsError(
        'failed-precondition',
        'PLAY_SERVICE_ACCOUNT is missing client_email or private_key.',
      );
    }

    const client = new JWT({
      email: credentials.client_email,
      key: credentials.private_key,
      scopes: [PLAY_SCOPE],
    });
    const url =
      'https://androidpublisher.googleapis.com/androidpublisher/v3' +
      `/applications/${PACKAGE_NAME}/purchases/subscriptionsv2/tokens/` +
      encodeURIComponent(purchaseToken);

    let purchase: PlaySubscriptionPurchase;
    try {
      const response = await client.request<PlaySubscriptionPurchase>({ url });
      purchase = response.data;
    } catch (error) {
      logger.warn('Play Developer API verification failed', error);
      throw new HttpsError(
        'invalid-argument',
        'Google Play could not verify this purchase.',
      );
    }

    const lineItem = (purchase.lineItems ?? []).find(
      (item) => item.productId === productId,
    );
    if (!lineItem || !lineItem.expiryTime) {
      throw new HttpsError(
        'invalid-argument',
        'This purchase is not for a premium plan.',
      );
    }

    const expiry = new Date(lineItem.expiryTime);
    const entitled =
      ENTITLED_STATES.has(purchase.subscriptionState ?? '') &&
      expiry.getTime() > Date.now();

    await db.doc(`users/${uid}`).set(
      {
        isPremium: entitled,
        premiumUntil: entitled ? Timestamp.fromDate(expiry) : null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return {
      entitled,
      premiumUntil: entitled ? expiry.toISOString() : null,
    };
  },
);
