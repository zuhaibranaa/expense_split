/**
 * Security-rules tests for Firestore and Storage.
 *
 * Run with the emulators:
 *   firebase emulators:exec --only firestore,storage --project=equisplit-d4c74 \
 *     "npm --prefix functions test"
 *
 * Every `assertSucceeds` below has a matching `assertFails` counterpart in the
 * same block, per AGENTS.md §7.
 */
const fs = require('node:fs');
const path = require('node:path');
const { after, before, beforeEach, describe, test } = require('node:test');
const assert = require('node:assert/strict');

const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');
require('firebase/compat/storage');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const ROOT = path.join(__dirname, '..', '..');
const PROJECT_ID = process.env.GCLOUD_PROJECT || 'equisplit-d4c74';
const now = () => firebase.firestore.Timestamp.fromDate(new Date());

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(path.join(ROOT, 'firestore.rules'), 'utf8'),
    },
    storage: {
      rules: fs.readFileSync(path.join(ROOT, 'storage.rules'), 'utf8'),
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    const users = [
      ['alice', { name: 'Alice', isPremium: false }],
      ['bob', { name: 'Bob', isPremium: false }],
      ['carol', { name: 'Carol', isPremium: true }],
      ['dave', { name: 'Dave', isPremium: false }],
    ];

    for (const [uid, extra] of users) {
      await db.doc(`users/${uid}`).set({
        uid,
        name: extra.name,
        email: `${uid}@example.com`,
        avatarUrl: null,
        defaultCurrency: 'EUR',
        phone: null,
        iban: null,
        isPremium: extra.isPremium,
        premiumUntil: null,
        hasPassword: true,
        personalGroupId: null,
        createdAt: now(),
        updatedAt: now(),
      });
    }

    await db.doc('groups/g1').set({
      name: 'Trip',
      currency: 'EUR',
      type: 'REGULAR',
      ownerUid: 'alice',
      memberUids: ['alice', 'bob'],
      createdAt: now(),
      updatedAt: now(),
      lastActivityAt: now(),
    });

    await db.doc('groups/g1/members/alice').set({
      name: 'Alice',
      uid: 'alice',
      email: 'alice@example.com',
      avatarUrl: null,
      isAdmin: true,
      isRemoved: false,
      hasFcmToken: false,
    });
    await db.doc('groups/g1/members/bob').set({
      name: 'Bob',
      uid: 'bob',
      email: 'bob@example.com',
      avatarUrl: null,
      isAdmin: false,
      isRemoved: false,
      hasFcmToken: false,
    });
    // Placeholder member that has not signed up yet.
    await db.doc('groups/g1/members/placeholder').set({
      name: 'Invitee',
      uid: null,
      email: 'invitee@example.com',
      avatarUrl: null,
      isAdmin: false,
      isRemoved: false,
      hasFcmToken: false,
    });

    await db.doc('groups/g2').set({
      name: 'Other',
      currency: 'EUR',
      type: 'REGULAR',
      ownerUid: 'dave',
      memberUids: ['dave'],
      createdAt: now(),
      updatedAt: now(),
      lastActivityAt: now(),
    });

    await db.doc('groups/g1/expenses/e1').set({
      description: 'Dinner',
      amount: 30,
      category: 'food-drinks',
      payerId: 'alice',
      payerName: 'Alice',
      date: now(),
      isSettlement: false,
      splits: [
        { memberId: 'alice', amount: 15 },
        { memberId: 'bob', amount: 15 },
      ],
      payments: [],
      memberIds: ['alice', 'bob'],
      createdBy: 'alice',
      createdAt: now(),
      updatedAt: now(),
    });

    await db.doc('cashInflows/f1').set({
      uid: 'alice',
      amount: 100,
      currencyCode: 'EUR',
      category: 'salary',
      description: 'Salary',
      date: now(),
      expenseId: null,
      createdAt: now(),
    });

    await db.doc('invites/token123').set({
      groupId: 'g1',
      memberId: 'placeholder',
      createdBy: 'alice',
      createdAt: now(),
      expiresAt: now(),
      used: false,
    });

    await db.doc('reminders/alice_bob_20260101').set({
      fromUid: 'alice',
      toUid: 'bob',
      groupId: 'g1',
      createdAt: now(),
    });
  });
});

const as = (uid) => testEnv.authenticatedContext(uid);
const anon = () => testEnv.unauthenticatedContext();

function validExpense(overrides = {}) {
  return {
    description: 'Lunch',
    amount: 20,
    category: 'food-drinks',
    payerId: 'alice',
    payerName: 'Alice',
    date: now(),
    isSettlement: false,
    splits: [
      { memberId: 'alice', amount: 10 },
      { memberId: 'bob', amount: 10 },
    ],
    payments: [],
    memberIds: ['alice', 'bob'],
    createdBy: 'alice',
    createdAt: now(),
    updatedAt: now(),
    ...overrides,
  };
}

describe('users', () => {
  test('signed-out cannot read a profile', async () => {
    await assertFails(anon().firestore().doc('users/alice').get());
  });

  test('self can read and update the profile', async () => {
    await assertSucceeds(as('alice').firestore().doc('users/alice').get());
    await assertSucceeds(
      as('alice').firestore().doc('users/alice').update({ name: 'Alice B' }),
    );
  });

  test('other users cannot read or write a profile', async () => {
    await assertFails(as('bob').firestore().doc('users/alice').get());
    await assertFails(
      as('bob').firestore().doc('users/alice').update({ name: 'Hacked' }),
    );
  });

  test('create requires uid to equal the document id', async () => {
    const profile = {
      name: 'Erin',
      email: 'erin@example.com',
      createdAt: now(),
      updatedAt: now(),
    };
    await assertFails(
      as('erin').firestore().doc('users/erin').set({ ...profile, uid: 'alice' }),
    );
    await assertSucceeds(
      as('erin').firestore().doc('users/erin').set({ ...profile, uid: 'erin' }),
    );
  });

  test('a full set() cannot drop admin-only premium fields', async () => {
    await assertFails(
      as('carol').firestore().doc('users/carol').set({
        uid: 'carol',
        name: 'Carol',
        email: 'carol@example.com',
        createdAt: now(),
        updatedAt: now(),
      }),
    );
  });

  test('isPremium cannot be set on create or update', async () => {
    await assertFails(
      as('dave').firestore().doc('users/dave').set({
        uid: 'dave',
        name: 'Dave',
        email: 'dave@example.com',
        isPremium: true,
        createdAt: now(),
        updatedAt: now(),
      }),
    );
    await assertFails(
      as('bob').firestore().doc('users/bob').update({ isPremium: true }),
    );
    await assertFails(
      as('bob').firestore().doc('users/bob').update({ premiumUntil: now() }),
    );
  });

  test('devices are self-only', async () => {
    await assertSucceeds(
      as('alice').firestore().doc('users/alice/devices/d1').set({
        token: 'abc',
        platform: 'web',
        updatedAt: now(),
      }),
    );
    await assertFails(
      as('bob').firestore().doc('users/alice/devices/d2').set({
        token: 'abc',
        platform: 'web',
        updatedAt: now(),
      }),
    );
    await assertFails(as('bob').firestore().doc('users/alice/devices/d1').get());
  });
});

describe('groups', () => {
  test('signed-out cannot read a group', async () => {
    await assertFails(anon().firestore().doc('groups/g1').get());
  });

  test('members can read, non-members cannot', async () => {
    await assertSucceeds(as('alice').firestore().doc('groups/g1').get());
    await assertSucceeds(as('bob').firestore().doc('groups/g1').get());
    await assertFails(as('dave').firestore().doc('groups/g1').get());
  });

  test('listing without the memberUids filter is denied', async () => {
    await assertFails(as('alice').firestore().collection('groups').get());
    await assertFails(
      as('alice').firestore().collection('groups').where('ownerUid', '==', 'alice').get(),
    );
    const snapshot = await assertSucceeds(
      as('alice')
        .firestore()
        .collection('groups')
        .where('memberUids', 'array-contains', 'alice')
        .get(),
    );
    assert.deepEqual(
      snapshot.docs.map((doc) => doc.id),
      ['g1'],
    );
  });

  test('create requires the caller to own and join the group', async () => {
    const base = {
      name: 'New',
      currency: 'EUR',
      type: 'REGULAR',
      createdAt: now(),
      updatedAt: now(),
      lastActivityAt: now(),
    };
    await assertFails(
      as('bob').firestore().doc('groups/g3').set({
        ...base,
        ownerUid: 'alice',
        memberUids: ['alice', 'bob'],
      }),
    );
    await assertFails(
      as('bob').firestore().doc('groups/g3').set({
        ...base,
        ownerUid: 'bob',
        memberUids: ['alice'],
      }),
    );
    await assertFails(
      as('bob').firestore().doc('groups/g3').set({
        ...base,
        name: '',
        ownerUid: 'bob',
        memberUids: ['bob'],
      }),
    );
    await assertSucceeds(
      as('bob').firestore().doc('groups/g3').set({
        ...base,
        ownerUid: 'bob',
        memberUids: ['bob'],
      }),
    );
  });

  test('only the owner can update, and only non-structural fields', async () => {
    await assertFails(
      as('bob').firestore().doc('groups/g1').update({ name: 'Renamed' }),
    );
    await assertSucceeds(
      as('alice').firestore().doc('groups/g1').update({ name: 'Renamed' }),
    );
    await assertFails(
      as('alice').firestore().doc('groups/g1').update({ ownerUid: 'bob' }),
    );
    await assertFails(
      as('alice')
        .firestore()
        .doc('groups/g1')
        .update({ memberUids: ['alice', 'bob', 'carol'] }),
    );
    await assertFails(
      as('alice').firestore().doc('groups/g1').update({ type: 'PERSONAL' }),
    );
    await assertFails(
      as('alice').firestore().doc('groups/g1').update({ createdAt: now() }),
    );
  });

  test('client deletes are always denied', async () => {
    await assertFails(as('alice').firestore().doc('groups/g1').delete());
  });
});

describe('members', () => {
  test('members can read member documents, outsiders cannot', async () => {
    await assertSucceeds(as('bob').firestore().doc('groups/g1/members/alice').get());
    await assertFails(as('dave').firestore().doc('groups/g1/members/alice').get());
  });

  test('a member can add an unclaimed placeholder member', async () => {
    await assertSucceeds(
      as('bob').firestore().doc('groups/g1/members/placeholder2').set({
        name: 'New person',
        uid: null,
        email: 'new@example.com',
        avatarUrl: null,
        isAdmin: false,
        isRemoved: false,
        hasFcmToken: false,
      }),
    );
    await assertFails(
      as('dave').firestore().doc('groups/g1/members/placeholder3').set({
        name: 'Intruder',
        uid: null,
        email: 'x@example.com',
        avatarUrl: null,
        isAdmin: false,
        isRemoved: false,
        hasFcmToken: false,
      }),
    );
  });

  test('placeholder create cannot claim a uid, be admin, or be removed', async () => {
    const base = {
      name: 'New person',
      email: 'new@example.com',
      avatarUrl: null,
      isAdmin: false,
      isRemoved: false,
      hasFcmToken: false,
    };
    await assertFails(
      as('bob').firestore().doc('groups/g1/members/p1').set({
        ...base,
        uid: 'carol',
      }),
    );
    await assertFails(
      as('bob').firestore().doc('groups/g1/members/p2').set({
        ...base,
        uid: null,
        isAdmin: true,
      }),
    );
    await assertFails(
      as('bob').firestore().doc('groups/g1/members/p3').set({
        ...base,
        uid: null,
        isRemoved: true,
      }),
    );
  });

  test('a member can update their own display fields only', async () => {
    await assertSucceeds(
      as('bob').firestore().doc('groups/g1/members/bob').update({
        name: 'Bobby',
        avatarUrl: 'https://example.com/b.png',
        hasFcmToken: true,
      }),
    );
    await assertFails(
      as('bob').firestore().doc('groups/g1/members/bob').update({ isAdmin: true }),
    );
    await assertFails(
      as('bob').firestore().doc('groups/g1/members/bob').update({ isRemoved: true }),
    );
    await assertFails(
      as('bob').firestore().doc('groups/g1/members/alice').update({ name: 'Hacked' }),
    );
  });

  test('members cannot delete member documents', async () => {
    await assertFails(as('alice').firestore().doc('groups/g1/members/bob').delete());
  });
});

describe('expenses', () => {
  test('members can read, outsiders cannot', async () => {
    await assertSucceeds(as('bob').firestore().doc('groups/g1/expenses/e1').get());
    await assertFails(as('dave').firestore().doc('groups/g1/expenses/e1').get());
  });

  test('a valid expense can be created by a member', async () => {
    await assertSucceeds(
      as('bob').firestore().doc('groups/g1/expenses/e2').set(
        validExpense({ createdBy: 'bob' }),
      ),
    );
  });

  test('invalid expenses are rejected', async () => {
    const invalid = [
      validExpense({ amount: 0 }),
      validExpense({ amount: -5 }),
      validExpense({ description: '' }),
      validExpense({ splits: [] }),
      validExpense({ payerId: 'carol' }),
      validExpense({ memberIds: [] }),
      validExpense({ category: 42 }),
    ];
    for (const [index, data] of invalid.entries()) {
      await assertFails(
        as('alice').firestore().doc(`groups/g1/expenses/bad${index}`).set(data),
      );
    }
  });

  test('non-members cannot create expenses', async () => {
    await assertFails(
      as('dave').firestore().doc('groups/g1/expenses/e3').set(
        validExpense({ createdBy: 'dave' }),
      ),
    );
  });

  test('createdBy must be the caller', async () => {
    await assertFails(
      as('bob').firestore().doc('groups/g1/expenses/e4').set(validExpense()),
    );
  });

  test('creator and owner can update/delete; other members cannot', async () => {
    await assertSucceeds(
      as('alice').firestore().doc('groups/g1/expenses/e1').update({ amount: 42 }),
    );
    // Bob is a member but neither creator nor owner.
    await assertFails(
      as('bob').firestore().doc('groups/g1/expenses/e1').update({ amount: 1 }),
    );
    await assertFails(as('bob').firestore().doc('groups/g1/expenses/e1').delete());
    await assertSucceeds(as('alice').firestore().doc('groups/g1/expenses/e1').get());

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('groups/g1/expenses/e1').update({ createdBy: 'bob' });
    });
    // Bob is now the creator: he may edit and delete, Alice (owner) still may too
    // through the owner branch.
    await assertSucceeds(as('bob').firestore().doc('groups/g1/expenses/e1').update({ amount: 50 }));
    await assertFails(
      as('dave').firestore().doc('groups/g1/expenses/e1').update({ amount: 60 }),
    );
    await assertSucceeds(as('bob').firestore().doc('groups/g1/expenses/e1').delete());
  });
});

describe('categories', () => {
  test('members can read, outsiders cannot', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('groups/g1/categories/general').set({
        name: 'General',
        icon: '🧾',
        createdAt: now(),
      });
    });
    await assertSucceeds(
      as('bob').firestore().doc('groups/g1/categories/general').get(),
    );
    await assertFails(
      as('dave').firestore().doc('groups/g1/categories/general').get(),
    );
  });

  test('only premium members can create categories', async () => {
    const category = { name: 'Pets', icon: '🐶', createdAt: now() };
    await assertFails(
      as('bob').firestore().doc('groups/g1/categories/pets').set(category),
    );
    await assertFails(
      as('dave').firestore().doc('groups/g1/categories/pets').set(category),
    );
    // Carol is premium but not a member of g1.
    await assertFails(
      as('carol').firestore().doc('groups/g1/categories/pets').set(category),
    );
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('groups/g1/categories/pets').set(category);
    });
    await assertSucceeds(
      as('bob').firestore().doc('groups/g1/categories/pets').get(),
    );
  });

  test('only the owner can rename or delete categories', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc('groups/g1/categories/pets').set({
        name: 'Pets',
        icon: '🐶',
        createdAt: now(),
      });
    });
    await assertFails(
      as('bob').firestore().doc('groups/g1/categories/pets').update({ name: 'Animals' }),
    );
    await assertSucceeds(
      as('alice').firestore().doc('groups/g1/categories/pets').update({ name: 'Animals' }),
    );
    await assertFails(as('bob').firestore().doc('groups/g1/categories/pets').delete());
    await assertSucceeds(as('alice').firestore().doc('groups/g1/categories/pets').delete());
  });
});

describe('invites, reminders and cash inflows', () => {
  test('clients can never read or write invites', async () => {
    await assertFails(as('alice').firestore().doc('invites/token123').get());
    await assertFails(as('alice').firestore().doc('invites/token123').delete());
    await assertFails(
      as('alice').firestore().doc('invites/new').set({
        groupId: 'g1',
        memberId: 'placeholder',
        createdBy: 'alice',
        createdAt: now(),
        expiresAt: now(),
        used: false,
      }),
    );
    await assertFails(as('alice').firestore().collection('invites').get());
  });

  test('clients can never read or write reminders', async () => {
    await assertFails(
      as('alice').firestore().doc('reminders/alice_bob_20260101').get(),
    );
    await assertFails(
      as('alice').firestore().doc('reminders/alice_bob_20260102').set({
        fromUid: 'alice',
        toUid: 'bob',
        groupId: 'g1',
        createdAt: now(),
      }),
    );
  });

  test('cash inflows are owner-only', async () => {
    await assertSucceeds(as('alice').firestore().doc('cashInflows/f1').get());
    await assertFails(as('bob').firestore().doc('cashInflows/f1').get());
    await assertFails(as('bob').firestore().doc('cashInflows/f1').delete());
    await assertFails(
      as('bob').firestore().doc('cashInflows/f2').set({
        uid: 'alice',
        amount: 10,
        currencyCode: 'EUR',
        category: 'gift',
        description: 'Gift',
        date: now(),
        expenseId: null,
        createdAt: now(),
      }),
    );
    await assertSucceeds(
      as('bob').firestore().doc('cashInflows/f2').set({
        uid: 'bob',
        amount: 10,
        currencyCode: 'EUR',
        category: 'gift',
        description: 'Gift',
        date: now(),
        expenseId: null,
        createdAt: now(),
      }),
    );
    await assertFails(
      as('bob').firestore().doc('cashInflows/f2').update({ amount: 0 }),
    );
    await assertSucceeds(
      as('bob').firestore().doc('cashInflows/f2').update({ amount: 20 }),
    );
    await assertSucceeds(as('bob').firestore().doc('cashInflows/f2').delete());
  });

  test('unknown collections are denied', async () => {
    await assertFails(as('alice').firestore().doc('secrets/x').get());
    await assertFails(as('alice').firestore().doc('secrets/x').set({ a: 1 }));
  });
});

describe('storage avatars', () => {
  const bytes = (size = 8) => new Uint8Array(size).fill(1);

  test('a user can upload an image to their own prefix', async () => {
    await assertSucceeds(
      as('alice')
        .storage()
        .ref('avatars/alice/profile.jpg')
        .put(bytes(), { contentType: 'image/jpeg' }),
    );
  });

  test('uploads to another uid prefix are denied', async () => {
    await assertFails(
      as('bob')
        .storage()
        .ref('avatars/alice/profile.jpg')
        .put(bytes(), { contentType: 'image/jpeg' }),
    );
  });

  test('non-image and oversized uploads are denied', async () => {
    await assertFails(
      as('alice')
        .storage()
        .ref('avatars/alice/profile.txt')
        .put(bytes(), { contentType: 'text/plain' }),
    );
    await assertFails(
      as('alice')
        .storage()
        .ref('avatars/alice/big.jpg')
        .put(bytes(5 * 1024 * 1024 + 1), { contentType: 'image/jpeg' }),
    );
  });

  test('signed-in users can read avatars; signed-out cannot', async () => {
    await as('alice')
      .storage()
      .ref('avatars/alice/profile.jpg')
      .put(bytes(), { contentType: 'image/jpeg' });

    await assertSucceeds(
      as('bob').storage().ref('avatars/alice/profile.jpg').getDownloadURL(),
    );
    await assertFails(
      anon().storage().ref('avatars/alice/profile.jpg').getDownloadURL(),
    );
  });

  test('unknown paths are denied', async () => {
    await assertFails(
      as('alice').storage().ref('other/file.jpg').put(bytes(), {
        contentType: 'image/jpeg',
      }),
    );
  });
});
