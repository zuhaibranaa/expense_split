/**
 * Emulator-backed golden path:
 * signup → personal group → group → invite → claim → expense → reset → remove → delete.
 *
 * Requires the auth, firestore and functions emulators:
 *   firebase emulators:exec --only auth,firestore,functions --project=equisplit-d4c74 \
 *     "npm --prefix functions run test:integration"
 *
 * The test uses the emulator REST APIs directly (no Flutter client) but goes
 * through the same security rules and callables the app uses. Skip silently
 * when the emulators are not running.
 */
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'equisplit-d4c74';
const AUTH_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const FIRESTORE_HOST = process.env.FIRESTORE_EMULATOR_HOST;
const FUNCTIONS_HOST = process.env.FUNCTIONS_EMULATOR_HOST || '127.0.0.1:5001';
const REGION = 'europe-west1';
const enabled = Boolean(AUTH_HOST && FIRESTORE_HOST);

const FS_BASE = `http://${FIRESTORE_HOST}/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const AUTH_BASE = `http://${AUTH_HOST}/identitytoolkit.googleapis.com/v1`;
const FN_BASE = `http://${FUNCTIONS_HOST}/${PROJECT_ID}/${REGION}`;

const skip = enabled ? false : 'auth/firestore/functions emulators are not running';

// ---------------------------------------------------------------------------
// Firestore REST encoding
// ---------------------------------------------------------------------------

function encodeValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeValue) } };
  }
  return { mapValue: { fields: encodeFields(value) } };
}

function encodeFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, encodeValue(value)]),
  );
}

function decodeValue(value) {
  if (!value) return undefined;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('timestampValue' in value) return new Date(value.timestampValue);
  if ('nullValue' in value) return null;
  if ('arrayValue' in value) {
    return (value.arrayValue.values ?? []).map(decodeValue);
  }
  if ('mapValue' in value) return decodeFields(value.mapValue.fields ?? {});
  return undefined;
}

function decodeFields(fields) {
  return Object.fromEntries(
    Object.entries(fields ?? {}).map(([key, value]) => [key, decodeValue(value)]),
  );
}

function decodeDoc(doc) {
  const id = doc.name.split('/').pop();
  return { id, ...decodeFields(doc.fields) };
}

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

async function request(method, url, { token, body } = {}) {
  const headers = { 'content-type': 'application/json' };
  if (token) headers.authorization = `Bearer ${token}`;
  const response = await fetch(url, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  let json = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = text;
    }
  }
  return { status: response.status, ok: response.ok, json };
}

async function signUp(label) {
  const email = `${label}-${randomUUID().slice(0, 8)}@example.com`;
  const password = 'test-password-123';
  const { status, json } = await request(
    'POST',
    `${AUTH_BASE}/accounts:signUp?key=fake-api-key`,
    { body: { email, password, returnSecureToken: true } },
  );
  assert.equal(status, 200, `signUp failed: ${JSON.stringify(json)}`);
  return { uid: json.localId, email, password, idToken: json.idToken };
}

async function createDoc(token, path, data) {
  const { status, json } = await request('POST', `${FS_BASE}/${path}`, {
    token,
    body: { fields: encodeFields(data) },
  });
  assert.equal(status, 200, `create ${path} failed: ${JSON.stringify(json)}`);
  return json.name.split('/').pop();
}

async function setDoc(token, path, data) {
  const { status, json } = await request('PATCH', `${FS_BASE}/${path}`, {
    token,
    body: { fields: encodeFields(data) },
  });
  assert.equal(status, 200, `set ${path} failed: ${JSON.stringify(json)}`);
  return decodeDoc(json);
}

async function updateDoc(token, path, data) {
  const mask = Object.keys(data)
    .map((key) => `updateMask.fieldPaths=${encodeURIComponent(key)}`)
    .join('&');
  const { status, json } = await request('PATCH', `${FS_BASE}/${path}?${mask}`, {
    token,
    body: { fields: encodeFields(data) },
  });
  assert.equal(status, 200, `update ${path} failed: ${JSON.stringify(json)}`);
  return decodeDoc(json);
}

async function getDoc(token, path) {
  return request('GET', `${FS_BASE}/${path}`, { token });
}

async function listDocs(token, path) {
  const { status, json } = await request('GET', `${FS_BASE}/${path}`, { token });
  assert.equal(status, 200, `list ${path} failed: ${JSON.stringify(json)}`);
  return (json.documents ?? []).map(decodeDoc);
}

async function callFn(name, token, data = {}) {
  const response = await request('POST', `${FN_BASE}/${name}`, {
    token,
    body: { data },
  });
  if (!response.ok) {
    const message = response.json?.error?.message ?? JSON.stringify(response.json);
    const error = new Error(`${name} failed: ${message}`);
    error.status = response.status;
    error.code = response.json?.error?.status;
    throw error;
  }
  return response.json?.result;
}

async function waitFor(description, fn, timeoutMs = 30000) {
  const deadline = Date.now() + timeoutMs;
  let last;
  while (Date.now() < deadline) {
    last = await fn();
    if (last) return last;
    await new Promise((resolve) => setTimeout(resolve, 400));
  }
  throw new Error(`Timed out waiting for ${description}`);
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const profile = (uid, name) => ({
  uid,
  name,
  email: `${name.toLowerCase()}@example.com`,
  avatarUrl: null,
  defaultCurrency: 'EUR',
  phone: null,
  iban: null,
  hasPassword: true,
  personalGroupId: null,
  createdAt: new Date(),
  updatedAt: new Date(),
});

function expenseData({ createdBy, payerId, memberIds }) {
  const share = memberIds.length ? Math.round((20 / memberIds.length) * 100) / 100 : 0;
  return {
    description: 'Dinner',
    amount: 20,
    category: 'food-drinks',
    payerId,
    payerName: 'Payer',
    date: new Date(),
    isSettlement: false,
    splits: memberIds.map((memberId) => ({ memberId, amount: share })),
    payments: [],
    memberIds,
    createdBy,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
}

test('rules + functions golden path', { skip }, async (t) => {
  const alice = await signUp('alice');
  const bob = await signUp('bob');
  const dave = await signUp('dave');

  await t.test('signup bootstraps a personal group with seeded categories', async () => {
    await setDoc(alice.idToken, `users/${alice.uid}`, profile(alice.uid, 'Alice'));

    const personalGroupId = await waitFor('personalGroupId', async () => {
      const { json } = await getDoc(alice.idToken, `users/${alice.uid}`);
      return decodeFields(json.fields).personalGroupId;
    });

    const { json } = await getDoc(alice.idToken, `groups/${personalGroupId}`);
    const personalGroup = decodeFields(json.fields);
    assert.equal(personalGroup.type, 'PERSONAL');
    assert.equal(personalGroup.ownerUid, alice.uid);
    assert.deepEqual(personalGroup.memberUids, [alice.uid]);

    const categories = await waitFor('seeded categories', async () => {
      const docs = await listDocs(alice.idToken, `groups/${personalGroupId}/categories`);
      return docs.length === 9 ? docs : null;
    });
    assert.deepEqual(
      categories.map((category) => category.id).sort(),
      [
        'entertainment',
        'food-drinks',
        'general',
        'housing',
        'life',
        'other',
        'shopping',
        'transportation',
        'utilities',
      ],
    );
  });

  let groupId;
  let memberId;

  await t.test('creating a group seeds categories and yields an invite', async () => {
    groupId = await createDoc(alice.idToken, 'groups', {
      name: 'Trip',
      currency: 'EUR',
      type: 'REGULAR',
      ownerUid: alice.uid,
      memberUids: [alice.uid],
      createdAt: new Date(),
      updatedAt: new Date(),
      lastActivityAt: new Date(),
    });

    await setDoc(alice.idToken, `groups/${groupId}/members/${alice.uid}`, {
      name: 'Alice',
      uid: alice.uid,
      email: alice.email,
      avatarUrl: null,
      isAdmin: true,
      isRemoved: false,
      hasFcmToken: false,
      createdAt: new Date(),
    });

    memberId = await createDoc(alice.idToken, `groups/${groupId}/members`, {
      name: 'Bob',
      uid: null,
      email: bob.email,
      avatarUrl: null,
      isAdmin: false,
      isRemoved: false,
      hasFcmToken: false,
    });

    const categories = await waitFor('group categories', async () => {
      const docs = await listDocs(alice.idToken, `groups/${groupId}/categories`);
      return docs.length === 9 ? docs : null;
    });
    assert.equal(categories.length, 9);

    const invite = await callFn('createInvite', alice.idToken, { groupId, memberId });
    assert.match(invite.url, /^https:\/\/equisplit-d4c74\.web\.app\/join\?token=/);
    assert.equal(invite.token.length >= 32, true);

    // A non-member may not mint invites.
    const error = await callFn('createInvite', dave.idToken, { groupId, memberId })
      .then(() => null)
      .catch((err) => err);
    assert.ok(error, 'non-member invite should fail');
    assert.equal(error.status, 403);
  });

  await t.test('claiming the invite links the member and is single-use', async () => {
    await setDoc(bob.idToken, `users/${bob.uid}`, profile(bob.uid, 'Bob'));
    await waitFor('bob personal group', async () => {
      const { json } = await getDoc(bob.idToken, `users/${bob.uid}`);
      return decodeFields(json.fields).personalGroupId;
    });

    const { json: inviteDoc } = await getDoc(alice.idToken, `groups/${groupId}`);
    assert.ok(decodeDoc(inviteDoc));

    const invite = await callFn('createInvite', alice.idToken, { groupId, memberId });
    const claim = await callFn('claimInvite', bob.idToken, { token: invite.token });

    assert.equal(claim.groupId, groupId);
    assert.equal(claim.groupName, 'Trip');

    const claimedGroup = await getDoc(bob.idToken, `groups/${groupId}`);
    assert.equal(claimedGroup.status, 200);
    assert.deepEqual(
      decodeFields(claimedGroup.json.fields).memberUids.sort(),
      [alice.uid, bob.uid].sort(),
    );

    const { json: memberJson } = await getDoc(
      alice.idToken,
      `groups/${groupId}/members/${memberId}`,
    );
    assert.equal(decodeFields(memberJson.fields).uid, bob.uid);

    // The invite document is consumed, so a second claim cannot find it.
    const second = await callFn('claimInvite', bob.idToken, {
      token: invite.token,
    }).catch((err) => err);
    assert.equal(second.status, 404);

    // Minting another invite for the now-linked member is rejected.
    const linked = await callFn('createInvite', alice.idToken, { groupId, memberId })
      .catch((err) => err);
    assert.equal(linked.status, 400, 'already-linked members are rejected');

    const badClaim = await callFn('claimInvite', dave.idToken, {
      token: 'not-a-real-token',
    }).catch((err) => err);
    assert.equal(badClaim.status, 404);
  });

  await t.test('expenses follow the rules for members only', async () => {
    const before = decodeFields(
      (await getDoc(alice.idToken, `groups/${groupId}`)).json.fields,
    ).lastActivityAt;

    const expenseId = await createDoc(
      alice.idToken,
      `groups/${groupId}/expenses`,
      expenseData({
        createdBy: alice.uid,
        payerId: alice.uid,
        memberIds: [alice.uid, bob.uid],
      }),
    );

    await waitFor('lastActivityAt bump', async () => {
      const { json } = await getDoc(alice.idToken, `groups/${groupId}`);
      const lastActivityAt = decodeFields(json.fields).lastActivityAt;
      return lastActivityAt.getTime() > before.getTime();
    });

    assert.equal((await getDoc(bob.idToken, `groups/${groupId}/expenses/${expenseId}`)).status, 200);
    assert.equal((await getDoc(dave.idToken, `groups/${groupId}/expenses/${expenseId}`)).status, 403);

    const invalid = await request('POST', `${FS_BASE}/groups/${groupId}/expenses`, {
      token: alice.idToken,
      body: {
        fields: encodeFields(
          expenseData({
            createdBy: alice.uid,
            payerId: alice.uid,
            memberIds: [alice.uid, bob.uid],
          }),
        ),
      },
    });
    assert.equal(invalid.status, 200);

    const zeroAmount = await request('POST', `${FS_BASE}/groups/${groupId}/expenses`, {
      token: alice.idToken,
      body: {
        fields: encodeFields({
          ...expenseData({
            createdBy: alice.uid,
            payerId: alice.uid,
            memberIds: [alice.uid, bob.uid],
          }),
          amount: 0,
        }),
      },
    });
    assert.equal(zeroAmount.status, 403, 'amount <= 0 is rejected');
  });

  await t.test('resetPersonalBalance clears only personal data', async () => {
    const { json: userJson } = await getDoc(alice.idToken, `users/${alice.uid}`);
    const personalGroupId = decodeFields(userJson.fields).personalGroupId;

    const personalExpense = await createDoc(
      alice.idToken,
      `groups/${personalGroupId}/expenses`,
      expenseData({
        createdBy: alice.uid,
        payerId: alice.uid,
        memberIds: [alice.uid],
      }),
    );
    const inflowId = await createDoc(alice.idToken, 'cashInflows', {
      uid: alice.uid,
      amount: 500,
      currencyCode: 'EUR',
      category: 'salary',
      description: 'Salary',
      date: new Date(),
      expenseId: null,
      createdAt: new Date(),
    });

    const result = await callFn('resetPersonalBalance', alice.idToken);
    assert.equal(result.deletedExpenses, 1);
    assert.equal(result.deletedInflows, 1);

    // A deleted document either 404s or is rejected by the rules `get()` on
    // missing parent data; both mean the data is gone.
    const goneExpense = await getDoc(
      alice.idToken,
      `groups/${personalGroupId}/expenses/${personalExpense}`,
    );
    assert.ok([403, 404].includes(goneExpense.status));
    const goneInflow = await getDoc(alice.idToken, `cashInflows/${inflowId}`);
    assert.ok([403, 404].includes(goneInflow.status));
  });

  await t.test('settlement reminders validate the pair and devices', async () => {
    const toSelf = await callFn('sendSettlementReminder', alice.idToken, {
      toUid: alice.uid,
      groupId,
    }).catch((err) => err);
    assert.equal(toSelf.status, 400);

    const outsider = await callFn('sendSettlementReminder', dave.idToken, {
      toUid: bob.uid,
      groupId,
    }).catch((err) => err);
    assert.equal(outsider.status, 403);

    // Bob has no device documents in this test fixture.
    const noDevices = await callFn('sendSettlementReminder', alice.idToken, {
      toUid: bob.uid,
      groupId,
    }).catch((err) => err);
    assert.equal(noDevices.status, 400);
    assert.match(noDevices.message, /not enabled notifications/);
  });

  await t.test('removeMember and deleteGroup are callable-only', async () => {
    const removal = await callFn('removeMember', alice.idToken, {
      groupId,
      memberId,
    });
    assert.equal(removal.removed, true);

    const { json: groupJson } = await getDoc(alice.idToken, `groups/${groupId}`);
    assert.deepEqual(decodeFields(groupJson.fields).memberUids, [alice.uid]);

    const { json: memberJson } = await getDoc(
      alice.idToken,
      `groups/${groupId}/members/${memberId}`,
    );
    assert.equal(decodeFields(memberJson.fields).isRemoved, true);

    const denied = await callFn('deleteGroup', bob.idToken, { groupId }).catch(
      (err) => err,
    );
    assert.equal(denied.status, 403);

    const deleted = await callFn('deleteGroup', alice.idToken, { groupId });
    assert.equal(deleted.deleted, true);
    const gone = await getDoc(alice.idToken, `groups/${groupId}`);
    assert.ok([403, 404].includes(gone.status));
  });
});
