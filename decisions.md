# EquiSplit — Architecture Decisions

**Status:** Implemented (Phases 0–3); deployed rules, indexes, hosting; parity QA pending
**Date:** 2026-10-29 (updated 2026-10-30)
**Applies to:** `expense_split/` (Flutter client) and the retirement of the companion `equisplit/` Laravel API.
**Firebase project:** `equisplit-d4c74` (already configured in `firebase.json` and `lib/firebase_options.dart`).

> This file is the contract for the Firebase migration. It records *what* was decided and *why*.
> If implementation needs to deviate, update this file first — do not silently diverge.
> Implementation instructions for agents live in [`AGENTS.md`](AGENTS.md).

---

## 1. Context

The app is a Flutter expense-splitting client (`pubspec.yaml` name: `equisplit`) that currently talks to a Laravel 12 API in the sibling `equisplit/` repository:

- Auth: Laravel Sanctum bearer tokens, Google ID-token verification, email verification, password reset.
- Data: MySQL/Postgres via Eloquent — users, groups, members, expenses, splits, payments, categories, cash inflows.
- Real-time: Pusher/Soketi broadcasts (the Flutter app never actually subscribes).
- Push: Laravel sends FCM messages with the Kreait Admin SDK.
- Files: avatar upload to the Laravel API, then Cloudinary.
- Jobs: personal-balance reset/sync (`ResetPersonalBalanceJob`, `SyncPersonalFromExpensesJob`).
- Local persistence: Drift/SQLite is declared in `pubspec.yaml` but **not used anywhere in `lib/`**.

The goal is to remove the Laravel backend entirely and run on Firebase: **Auth + Firestore + Storage + Cloud Functions + FCM**, with no API server in the request path.

Two facts make this migration cheaper than usual:

1. Balance/settlement math is already client-side and pure (`lib/src/features/expenses/domain/balance_calculator.dart`).
2. Analytics and statistics are already aggregated in the client from per-group expense lists.

So the backend is mostly CRUD + auth + notifications, which Firebase replaces directly.

**Implementation state (2026-10-30):** Phases 0–3 are implemented in this repo — Firebase bootstrap, models with `String` IDs, Firestore repositories/providers, security rules + indexes, Storage rules, and the Cloud Functions in `functions/`. `flutter analyze` is clean, `flutter test` covers the pure layers, `flutter build web` succeeds, and `functions` compiles. Phase 4 (device parity QA) and Phase 5 (archive Laravel) remain.

---

## 2. Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Use Firebase as the only backend (Auth, Firestore, Storage, Functions, FCM); decommission Laravel | Accepted |
| D2 | Fresh start — no production data exists, no data migration, no legacy IDs | Accepted |
| D3 | Ship Android, iOS, Web, macOS, Windows; drop Linux | Accepted |
| D4 | Enable the Blaze plan; keep Cloud Functions inside the monthly no-cost quota | Accepted |
| D5 | Use Cloud Functions for signup bootstrap, invites, push sending, cleanup | Accepted |
| D6 | Firestore is the source of truth; rely on its offline persistence; delete Drift | Accepted |
| D7 | Derive the personal balance client-side; delete `users.balance` and both personal jobs | Accepted |
| D8 | Use Firestore `String` document IDs everywhere; never `int` IDs | Accepted |
| D9 | Embed splits and payments inside each expense document | Accepted |
| D10 | Keep stable synthetic member IDs; link accounts via a `uid` field on claim | Accepted |
| D11 | Put invites in a top-level `invites/{token}` collection, callable-only | Accepted |
| D12 | Put cash inflows in a top-level `cashInflows` collection keyed by `uid` | Accepted |
| D13 | Categories live in a group subcollection; premium gating enforced by rules/functions | Accepted |
| D14 | Store `iban` as a plain string (Firestore at-rest encryption only) | Accepted |
| D15 | Store avatars in Firebase Storage under `avatars/{uid}/` | Accepted |
| D16 | Store FCM tokens under `users/{uid}/devices/{tokenId}`; mirror `hasFcmToken` onto member docs | Accepted |
| D17 | Remove the "does this email exist?" check; login attempts sign-in and handles `user-not-found` | Accepted |
| D18 | Remove unused dependencies (Drift, Pusher, `go_router`, `rxdart`, `shared_preferences`, etc.); keep `http` for the avatar-URL check | Accepted |
| D19 | Upgrade all FlutterFire packages together to `firebase_core` 5.x family | Accepted |
| D20 | Keep all balance/settlement computation in the client; no server-side balance math | Accepted |
| D21 | Rules enforce membership/ownership; expense arithmetic is peer-trusted in v1 | Accepted risk |
| D22 | Keep `equisplit/` archived in git for reference until parity QA passes, then retire infra | Accepted |
| D23 | Invite links are HTTPS URLs (`/join?token=`); do not use Firebase Dynamic Links (shut down) | Accepted |
| D24 | Keep analytics client-side (per-group queries); no cross-group aggregation service | Accepted |
| D25 | Premium is an admin-set flag on the user doc; there is no purchase flow yet | Accepted |
| D26 | Money is stored as a Firestore `number` (double), rounded to 2 decimals at write boundaries | Accepted |
| D27 | Firestore has no unique constraints; enforce group/category name uniqueness in client code | Accepted |
| D28 | Keep the current feature-first folder structure and Riverpod patterns | Accepted |
| D29 | Keep existing screens/UX; refactor data layer underneath | Accepted |
| D30 | Use App Check on release builds (enforcement after parity) | Accepted |
| D31 | Deploy Firestore, Storage, and Functions to `europe-west1`; accept the small Storage cost difference | Accepted (2026-10-30) |
| D32 | "Reset personal balance" is the `resetPersonalBalance` callable (deletes personal-group expenses + own cash inflows) | Accepted (2026-10-30) |
| D33 | Default categories are seeded by `onGroupCreated` for every group; `bootstrapUser` seeds them idempotently for the personal group using deterministic doc IDs | Accepted (2026-10-30) |
| D34 | Settlement reminders are rate-limited with top-level `reminders/{fromUid}_{toUid}_{yyyyMMdd}` documents written by Functions only | Accepted (2026-10-30) |
| D35 | `users/{uid}.hasPassword` records whether an email/password credential exists, so Google-only accounts can link one | Accepted (2026-10-30) |
| D36 | `hasFcmToken` mirroring and member profile propagation run server-side (`onDeviceRegistered`, `onDeviceRemoved`, `syncMemberProfile`); clients never write cross-group member docs | Accepted (2026-10-30) |
| D37 | Invite links use the `INVITE_BASE_URL` Cloud Functions parameter (default `https://equisplit-d4c74.web.app`) | Accepted (2026-10-30) |
| D38 | Verification runs on the Firebase emulators: `@firebase/rules-unit-testing` + `node:test` for rules, and a REST-driven golden-path test for functions/rules. The emulator suite requires JDK 21+ | Accepted (2026-10-30) |

### D1 — Firebase only

Use the existing Firebase project. Delete `lib/src/shared/data/api_client.dart` and `lib/src/config/environment.dart`; no feature may call an HTTP API after the migration. The Laravel repo is reference-only.

### D2 — Fresh start

There is no production data. Start with an empty Firestore. Do **not** write migration scripts, bcrypt imports, `legacyId` fields, or dual-write logic. Existing staging data is disposable.

### D3 — Platforms

FlutterFire supports Auth/Firestore/Storage on Android, iOS, Web, macOS, and Windows as of current versions. Linux is not supported (the app is already broken there: `DefaultFirebaseOptions.currentPlatform` throws). Remove `linux/` and the Linux row from the README.

### D4 — Blaze / Cloud Functions cost

Functions require Blaze (billing account required). Monthly no-cost quota is generous: 2M invocations, 400K GB-seconds, 200K CPU-seconds, 5 GB egress, 120 Cloud Build min/day, 500 MB Artifact Registry. Expected spend for this app: **$0**. Set a **$5 budget alert**. Firestore free tier: 50K reads/day, 20K writes/day, 20K deletes/day, 1 GiB, 10 GiB egress/month. Auth: 50K MAU. FCM: free.

### D5 — Cloud Functions

Functions own operations that must not be trusted to a client or need Admin SDK access:

- `bootstrapUser` — create the personal group + owner member + default categories.
- `createInvite` / `claimInvite` — token creation and safe claiming.
- `onExpenseCreated` — send FCM to other group members.
- `sendSettlementReminder` — validate shared group, rate-limit, send.
- `removeMember`, `deleteGroup`, `onUserDelete`, `cleanupInvites`.
- Optional `syncMemberProfile` (denormalisation) and `createCategory` (uniqueness + premium).

Not moved to Functions: balance math, settlement suggestions, stats, group listing.

### D6 — Firestore + offline

Firestore's built-in persistence replaces the never-implemented Drift idea. Remove `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `path_provider`, `path`, `web/drift_worker*.js`, `web/sqlite3.wasm`. Pending writes must surface failures in the UI (SnackBar via the existing `GlobalErrorHandler`).

### D7 — Derived personal balance

Personal balance = `sum(cash inflows) − sum(personal group expenses)` computed from streams. Delete `users.balance`, `User.balance`, all `reloadUser()` calls made solely for balance, and both Laravel jobs. Do **not** auto-mirror group expenses into the personal group in v1. "Reset balance" becomes "delete personal expenses + inflows" implemented as a callable or client batch delete (choice left to implementation; if client-side, rules must allow deleting own docs).

### D8 — String IDs

Every model, provider family, route argument, and map key becomes `String`. This includes `BalanceCalculator` (`Map<int,double>` → `Map<String,double>`, `DebtNode.memberId`, `BalanceTransfer.from/toMemberId`). Never parse Firestore IDs with `int.parse`.

### D9 — Embedded splits/payments

`expenses/{eid}` contains `splits: [{memberId, amount}]` and `payments: [{memberId, amount}]`. This preserves `Expense`/`ExpenseSplit`/`ExpensePayment` semantics and lets one document read drive `BalanceCalculator`. Also store `payerName` and `memberIds` (union of payer/splits/payments) on the expense for display and filtering.

### D10 — Member identity

- A member document ID is **stable for the life of the group**.
- The creator/owner member uses their `uid` as the member doc ID.
- Placeholder members get auto-generated Firestore IDs.
- Claiming an invite sets `uid`, `name`, `email`, `avatarUrl`, `hasFcmToken` on the existing member doc and appends the uid to `groups/{gid}.memberUids`. **No expense documents are rewritten.**
- Removing a member sets `isRemoved: true`; never hard-delete while expenses reference it.

### D11 — Invites

`invites/{token}` = `{groupId, memberId, createdBy, createdAt, expiresAt, used}`. Only Cloud Functions can read/write it. `createInvite` returns `{token, url}`; `claimInvite` is transactional and rejects expired/used tokens and users already in the group.

### D12 — Cash inflows

Top-level `cashInflows/{id}` with `uid`, `amount`, `currencyCode`, `category`, `description`, `date`, `expenseId?`. Owner-only rules. Queries filter by `uid` and date range. The existing UI passes `groupId` to the inflows provider; keep the provider signature for minimal UI churn but ignore `groupId` in the query (matches current backend behaviour).

### D13 — Categories

`groups/{gid}/categories/{cid}`. All groups (including personal) are seeded with the defaults below by `bootstrapUser`/group creation. Creating custom categories requires premium (rules + UI). Deleting a category is admin-only and should be blocked client-side if any expense uses it (Firestore has no FK; check before delete). Name uniqueness is enforced in client code.

Default categories (from Laravel `config/categories.php`):

| Name | Icon |
|---|---|
| General | 📝 |
| Food & Drinks | 🍔 |
| Transportation | 🚗 |
| Entertainment | 🎬 |
| Shopping | 🛍️ |
| Utilities | 💡 |
| Housing | 🏠 |
| Life | 🧘 |
| Other | 📦 |

### D14 — IBAN

Plain `string` field on `users/{uid}`. Firestore encrypts at rest; no field-level encryption. Do not build a key-management scheme.

### D15 — Avatars

`avatars/{uid}/profile.jpg` in Storage; store the download URL in `users/{uid}.avatarUrl` and `groups/{gid}/members/{memberId}.avatarUrl`. Rules: owner-write, image content type, max 5 MB.

### D16 — Push tokens

`users/{uid}/devices/{tokenId}` = `{token, platform, updatedAt}`. On token refresh/login, upsert; on logout, delete. The reminder button checks `Member.hasFcmToken`. Clients cannot write member documents across groups, so `onDeviceRegistered` / `onDeviceRemoved` (Admin SDK) recalculate `hasFcmToken` on every member doc linked to the uid. Functions read device docs via the Admin SDK.

### D17 — Login without email enumeration

Firebase deliberately blocks `fetchSignInMethodsForEmail`. Remove `AuthRepository.checkEmail` and the two-step "does this email exist?" flow. Attempt `signInWithEmailAndPassword`; on `user-not-found` show "No account found — create one"; on `wrong-password` show an invalid-credentials error.

### D18 / D19 — Dependencies

Remove unused: `pusher_channels_flutter`, `web_socket_channel`, `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `path_provider`, `path`, `rxdart`, `go_router`, `flutter_secure_storage`, `uuid`.
`http` is deliberately **kept**: `profile_screen.dart` uses a `HEAD` request to validate a pasted avatar URL. That dialog was not rewritten, so the dependency stays until the flow is removed.
Add: `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_app_check`.
Upgrade the whole `firebase_*` family together (current `firebase_core 3.15.2` is incompatible with auth 7 / firestore 7 / storage 14; those require `firebase_core ^5.1.0`). Regenerate `lib/firebase_options.dart` with `flutterfire configure`; do not hand-edit it.

### D20 / D21 — Balance math and rules

`BalanceCalculator` stays the only implementation of "who owes whom", running on the client after reading a group's expenses. Firestore rules validate shape (types, positive amount, non-empty description/splits, member references) but cannot sum arrays, so "splits must total amount" is not enforced server-side in v1. This is acceptable because only invited group members can write expenses. If abuse becomes a concern, add an `addExpense` callable later.

### D22 — Backend retirement

Keep `equisplit/` in git (archive the repository) until parity QA is green. Then remove the staging API, Soketi, MySQL/Postgres, Redis, Cloudinary credentials, and rotate the Firebase service account. Do not delete history.

### D23 — Invite links

Use `https://<host>/join?token=<token>` handled by `AuthGate`'s existing `Uri.base.queryParameters['token']` logic. Do not add Firebase Dynamic Links (discontinued).

### D24–D27 — Analytics, premium, money, uniqueness

- Stats remain client-side over per-group expense streams.
- Premium is `users/{uid}.isPremium` + `premiumUntil`; only Admin SDK may set it. UI hides/locks features; rules are the real gate.
- Amounts are doubles rounded to 2 decimals on write (consistent with the current app and `BalanceCalculator` rounding). A cents-based refactor is out of scope.
- Duplicate group/category names are checked in a transaction or function; Firestore cannot enforce uniqueness.

### D28 / D29 — Keep the app's shape

Do not restructure folders or rewrite UI for its own sake. Keep feature-first layout:

```
lib/src/features/{auth,home,groups,expenses,categories,cash_inflows,people,analytics}/
lib/src/shared/{presentation,services,utils}/
lib/src/core/firebase/          # new
```

Keep repository provider names and public method names where practical so screens change only for `String` IDs and stream types.

### D30 — App Check

Add App Check (Play Integrity / App Attest / reCAPTCHA) during Phase 0/1, but enable enforcement only after parity QA so development is not blocked. Callables should require App Check in production. Client wiring is behind the `ENABLE_APP_CHECK` dart-define and is off by default.

### D31 — Region

Firestore, Storage, and all Cloud Functions live in `europe-west1`. The client never hardcodes a region for Firestore (auto-discovered) but `FirebaseFunctions.instanceFor(region: 'europe-west1')` is used for callables; `functions/src/index.ts` sets it via `setGlobalOptions`. Storage therefore leaves the `us-central1` free-quota region — at this app's volume the extra cost is fractions of a cent, and keeping data in one region avoids cross-region latency.

### D32 — Reset personal balance

`resetPersonalBalance` (callable) deletes every expense in the caller's personal group and every `cashInflows` document owned by the caller, then returns `{deletedExpenses, deletedInflows}`. It exists instead of a client batch so the operation cannot be interrupted halfway and so the rules do not need to grant cross-collection batch rights. The UI keeps the existing "reset balance" affordance.

### D33 — Default categories

Two triggers seed the nine defaults:

- `onGroupCreated` seeds every new `groups/{gid}` (regular or personal) so non-premium users never need to write categories, which the rules deny.
- `bootstrapUser` seeds the personal group too, using the same deterministic IDs.

Deterministic doc IDs (`general`, `food-drinks`, `transportation`, `entertainment`, `shopping`, `utilities`, `housing`, `life`, `other`) make both paths idempotent — a re-run only refreshes `name`/`icon`. The list is duplicated in `lib/src/core/constants/default_categories.dart` and `functions/src/lib/constants.ts`; keep them in sync.

### D34 — Reminders

`sendSettlementReminder` writes `reminders/{fromUid}_{toUid}_{yyyyMMdd}` with `create()` (fails if it already exists) before sending. The collection is default-deny for clients; only the Admin SDK can read or write it. `cleanupInvites`-style retention for reminders is not needed at this scale (one tiny doc per pair per day).

### D35 — `hasPassword`

`users/{uid}.hasPassword` is written at registration (`true`) and on Google first sign-in (`false` if the provider list has no `password`). The profile screen uses it to decide whether changing a password requires the current password (reauthenticate) or should link an `EmailAuthProvider` credential. It is a client-writable profile field and is not a security boundary — Firebase Auth remains the authority.

### D36 — Server-side mirrors

Two pieces of denormalised state must not be written by clients:

- `hasFcmToken` on member docs (would require collection-group writes across groups the caller may not administer).
- `name` / `avatarUrl` on member docs after a profile edit (same reason).

`onDeviceRegistered`, `onDeviceRemoved`, and `syncMemberProfile` perform these updates with the Admin SDK after the corresponding user/device document changes. The client keeps only its own `users/{uid}` document in sync.

### D37 — Invite base URL

`createInvite` builds links from the `INVITE_BASE_URL` parameter (`defineString`, default `https://equisplit-d4c74.web.app`). Set it per environment (`firebase functions:config`-style params via `.env` or the deploy prompt) when a custom domain is used. Mobile deep links remain out of scope, consistent with D23.

### D38 — Emulator verification

Two automated suites run against the Firebase emulators:

- `functions/test/rules.test.js` uses `@firebase/rules-unit-testing` + Node's built-in `node:test` to exercise every deny path in `AGENTS.md` §7 against `firestore.rules` / `storage.rules`.
- `functions/test/integration/golden_path.test.js` drives the emulator REST APIs (Auth sign-up, Firestore documents, callable HTTP) to cover signup → personal group → invite → claim → expense → reminder guards → reset → remove → delete.

Both are plain JavaScript on purpose — the Functions project has no test bundler, and `node --test` needs no extra toolchain. `firebase-tools` requires **JDK 21+** for the emulators; a JDK 17 install fails at startup. `functions/.env.local` is generated by the emulator to store `INVITE_BASE_URL` and is git-ignored.

---

## 3. Target Firestore schema

```
users/{uid}
  uid: string                        // mirrors the document ID (rules check it)
  name: string
  email: string
  avatarUrl: string|null
  defaultCurrency: string            // e.g. "USD"
  phone: string|null
  iban: string|null
  isPremium: boolean                 // admin-only writes
  premiumUntil: Timestamp|null
  hasPassword: boolean               // true when an email/password credential exists
  personalGroupId: string|null       // set by bootstrapUser
  createdAt: Timestamp
  updatedAt: Timestamp
  devices/{tokenId}
    token: string
    platform: "android"|"ios"|"web"|"macos"|"windows"
    updatedAt: Timestamp

groups/{gid}
  name: string
  currency: string
  type: "REGULAR"|"PERSONAL"
  ownerUid: string
  memberUids: string[]               // used for listing + rules
  createdAt: Timestamp
  updatedAt: Timestamp
  lastActivityAt: Timestamp

  members/{memberId}
    name: string
    uid: string|null                 // set when an invite is claimed
    isAdmin: boolean
    isRemoved: boolean
    email: string|null
    phone: string|null
    avatarUrl: string|null
    hasFcmToken: boolean
    createdAt: Timestamp

  expenses/{expenseId}
    description: string
    amount: number
    currencyCode: string
    category: string
    date: Timestamp
    isSettlement: boolean
    payerId: string                  // member doc id
    payerName: string                // snapshot
    splits:   [{ memberId: string, amount: number }]
    payments: [{ memberId: string, amount: number }]
    memberIds: string[]              // union of payer + split + payment member ids
    createdBy: string                // uid
    createdAt: Timestamp
    updatedAt: Timestamp

  categories/{categoryId}
    name: string
    icon: string
    createdAt: Timestamp

invites/{token}
  groupId: string
  memberId: string
  createdBy: string
  createdAt: Timestamp
  expiresAt: Timestamp
  used: boolean

reminders/{fromUid}_{toUid}_{yyyyMMdd}
  fromUid: string
  toUid: string
  groupId: string
  createdAt: Timestamp                    // Functions-only collection

cashInflows/{inflowId}
  uid: string
  amount: number
  currencyCode: string
  category: string
  description: string
  date: Timestamp
  expenseId: string|null
  createdAt: Timestamp
```

### Required composite indexes

| Collection | Fields |
|---|---|
| `groups` | `memberUids` ARRAY_CONTAINS, `createdAt` DESC |
| `groups` | `memberUids` ARRAY_CONTAINS, `name` ASC |
| `expenses` (per group) | `memberIds` ARRAY_CONTAINS, `date` DESC |
| `cashInflows` | `uid` ASC, `date` DESC |
| `members` (collection group) | `uid` ASC |
| `members` (per group) | `uid` ASC, `isAdmin` ASC |

Firestore will emit "index required" links at runtime; add all discovered indexes to `firestore.indexes.json` in one pass.

---

## 4. Function inventory

| Function | Trigger | Responsibility |
|---|---|---|
| `bootstrapUser` | `onDocumentCreated users/{uid}` | Create personal group, owner member, seed default categories, set `personalGroupId`; idempotent |
| `onGroupCreated` | `onDocumentCreated groups/{gid}` | Seed the nine default categories for every new group |
| `createInvite` | callable | Validate caller is a member; create token doc with 7-day expiry; return URL |
| `claimInvite` | callable | Transaction: validate token, link member `uid`, update `memberUids`, delete invite |
| `onExpenseCreated` | `onDocumentCreated groups/{gid}/expenses/{eid}` | Notify other group members via FCM; update `lastActivityAt` |
| `sendSettlementReminder` | callable | Verify shared group; rate-limit via `reminders/*`; send FCM |
| `sendTestNotification` | callable | Debug button parity (self only) |
| `removeMember` | callable | Admin/owner only; `isRemoved = true`, remove uid from `memberUids` |
| `deleteGroup` | callable | Owner only; batched recursive delete |
| `resetPersonalBalance` | callable | Delete personal-group expenses and the caller's cash inflows |
| `onUserDelete` | Auth `onDelete` (v1) | Delete profile/devices/personal group; anonymise member docs |
| `cleanupInvites` | scheduled (daily 03:00) | Delete expired and used invites |
| `syncMemberProfile` | `onDocumentUpdated users/{uid}` | Propagate name/avatar changes to linked member docs |
| `onDeviceRegistered` | `onDocumentCreated users/{uid}/devices/{id}` | Set `hasFcmToken: true` on linked member docs |
| `onDeviceRemoved` | `onDocumentDeleted users/{uid}/devices/{id}` | Recalculate `hasFcmToken` from remaining devices |

`createCategory` was not implemented: custom-category creation is a direct client write gated by premium in the rules, with a client-side uniqueness check (D27). All functions deploy to `europe-west1` with `maxInstances: 10`, 256 MiB, 60 s (D31).

Two deliberate rule limitations:

- Expense update/delete is allowed to the creator and the group **owner**. Non-owner admins would require a member-document lookup keyed by `uid`, which rules cannot query; those operations can move behind a callable if it matters.
- Member `isRemoved` changes are Functions-only (the rule freezes that key), which is why removal must go through `removeMember`.

Push payloads should keep the current data keys (`type`, `group_id`, `expense_id`, `sender_id`, `amount`) so the existing `NotificationService` handling keeps working; values become strings.

---

## 5. Open decisions

Resolved during implementation: region (D31), personal reset (D32), invite base URL (D37), device/profile mirrors (D36).

Still open:

1. **App Check enforcement date** — after parity QA (D30).
2. **Arithmetic validation** — peer-trust (default, D21) vs `addExpense` callable later.
3. **Web hosting** — Firebase Hosting vs existing hosting. Does not affect the data layer; the default invite base URL assumes Firebase Hosting.
4. **Premium purchase** — out of scope; flag remains admin-set.

---

## 6. Rejected options

- **Keep Laravel as an API and only add Firebase Auth** — does not satisfy "get rid of the backend", and keeps two sources of truth.
- **Firestore + custom Node/Express API** — adds an unnecessary server; rules + callables cover the needs.
- **Keep Drift as a local cache in front of Firestore** — duplicate offline handling, more code, no benefit.
- **Key member documents by `uid`** — would force rewriting every expense's `memberId` on invite claim.
- **Store splits/payments in subcollections** — more reads, more complex transactions, no benefit at this scale.
- **Recreate `users.balance` via Functions** — drift-prone and unnecessary; derived balance is correct by construction.
- **Import bcrypt passwords / migrate staging data** — no production data; pure overhead.

---

## 7. Change protocol

1. Any change to schema, security rules, or a decision above requires editing this file in the same PR.
2. Add new decisions at the bottom with the next `D` number; do not renumber existing ones.
3. If an open decision is resolved, move it into the Decisions table and record the date.
4. Agents must follow [`AGENTS.md`](AGENTS.md); when it conflicts with this file, this file wins.
