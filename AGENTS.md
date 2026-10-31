# AGENTS.md — EquiSplit Firebase Migration

**Read this file before touching any code.**
Then read [`decisions.md`](decisions.md), which is the authoritative record of *what* was decided and *why*.

- If this file and `decisions.md` disagree, **`decisions.md` wins** — and this file should be corrected in the same change.
- If an implementation detail is not covered by either file, prefer the smallest change that keeps the existing UI/UX and repository/provider names intact.
- Never invent a new decision silently. Add it to `decisions.md` first (next `D` number), then implement.

---

## 1. Mission

Migrate `expense_split/` (Flutter app, package name `equisplit`) from the Laravel API in the sibling `equisplit/` repo to Firebase:

| Concern | Current | Target |
|---|---|---|
| Auth | Laravel Sanctum + Google ID-token endpoint | Firebase Auth (email/password + Google) |
| Data | Laravel REST API over SQL | Cloud Firestore (real-time listeners) |
| Real-time | Pusher/Soketi (never subscribed by the app) | Firestore snapshots |
| Push | Laravel + Kreait Admin SDK | Cloud Functions + FCM |
| Files | Laravel upload → Cloudinary | Firebase Storage |
| Local cache | Drift declared, unused | Firestore offline persistence |
| Balance | `users.balance` maintained by Laravel jobs | Derived client-side |
| Backend | Laravel 12 + DB + Redis + Soketi | None (archived) |

**End state:** the Flutter app talks only to Firebase. No HTTP API calls, no tokens in `SharedPreferences`, no Laravel in the request path.

**Current repo state:** the migration is **implemented** (Phases 0–3): the app reads/writes only Firebase, `functions/` is deployed-ready, rules/indexes/storage rules exist, and unit tests pass. What remains is Phase 4 device parity QA and Phase 5 archiving the Laravel repo. See [`decisions.md`](decisions.md) §1 and the progress log in §12.

---

## 2. Hard rules

1. **Firebase project is `equisplit-d4c74`.** It is already wired in `firebase.json`, `lib/firebase_options.dart`, `android/app/google-services.json`, and the Apple plists. Do not create a second project.
2. **No `int` IDs.** All Firestore document IDs, foreign keys, map keys, provider families, and route arguments are `String`. A single `int.parse` on an ID is a bug.
3. **No HTTP.** `lib/src/shared/data/api_client.dart` and `lib/src/config/environment.dart` are deleted, and nothing calls the Laravel API. `package:http` remains **only** for the avatar-URL `HEAD` check in `profile_screen.dart` (D18).
4. **No Laravel parity hacks.** Do not re-create `users.balance`, Pusher broadcasting, Sanctum tokens, the mirror/sync jobs, `checkEmail`, or Cloudinary uploads.
5. **Do not restructure the app.** Keep the feature-first layout in `lib/src/features/**` and the existing Riverpod provider names where possible (see §6). Refactor the data layer, not the screens.
6. **Keep `BalanceCalculator` logic.** It is the single implementation of settlement math and is already pure. Only the ID type changes (`int` → `String`). Do not reimplement rounding or the minimize/direct algorithms.
7. **Money** is a `double` rounded to 2 decimals at write boundaries. Do not introduce a cents-based model in this migration.
8. **No data migration.** Firestore starts empty. Do not write backfill scripts or `legacyId` fields.
9. **Secrets:** never commit service account JSON, `.env` files, or private keys. `firebase_options.dart` and the platform config files are public client config and stay committed.
10. **One phase per branch/PR.** Keep `flutter analyze` clean at the end of every phase; intermediate states may be broken only inside a phase branch.

---

## 3. Prerequisites and commands

### Toolchain

```bash
flutter --version          # Dart SDK ^3.10.0 (see pubspec.yaml)
dart --version
node --version             # Node 20 for Cloud Functions
npm --version
firebase --version         # npm i -g firebase-tools
flutterfire --version      # dart pub global activate flutterfire_cli
java -version              # JDK 21+ required by the Firebase emulators
```

### Day-to-day commands (run from `expense_split/`)

```bash
flutter pub get
flutter analyze
dart format lib
flutter test            # once a test/ directory exists

# Run targets
flutter run -d chrome
flutter run -d android
flutter run -d ios
flutter run -d macos
flutter run -d windows

# Firebase emulators (Auth, Firestore, Storage, Functions, UI)
firebase emulators:start

# Run the app against emulators (add this flag while implementing)
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true

# Rules tests only (exits non-zero on failure)
firebase emulators:exec --only firestore,storage "npm --prefix functions test"

# Full emulator golden path (auth + firestore + functions)
firebase emulators:exec --only auth,firestore,functions \
  "npm --prefix functions run test:integration"

# Deploy
firebase deploy --only firestore:rules,firestore:indexes,storage
firebase deploy --only functions
```

### Emulator wiring

`lib/src/core/firebase/firebase_bootstrap.dart` must connect emulators when `const bool.fromEnvironment('USE_FIREBASE_EMULATORS')` is true:

- Auth → `localhost:9099`
- Firestore → `localhost:8080`
- Storage → `localhost:9199`
- Functions → `localhost:5001`
- **Android emulator:** use `10.0.2.2`, not `localhost`.

Never ship emulator wiring behind anything other than that compile-time flag.

---

## 4. Implementation phases

Work in this order. Each phase lists the files to touch and its exit criteria. Do not start a phase before the previous one's exit criteria are met.

### Phase 0 — Firebase project setup (infra, ~0.5 day)

- [x] Enable Blaze + a **$5 budget alert**.
- [x] Enable Auth providers: Email/Password, Google.
- [x] Enable Firestore and Storage in `europe-west1` (D31).
- [x] Enable Cloud Functions, App Check (not enforced yet), FCM (Web Push certificate/VAPID already used in `NotificationService`).
- [x] Google sign-in config: Android SHA-1/SHA-256; iOS/macOS `GoogleService-Info.plist` URL scheme; Web authorized domains.
- [x] `firebase init` inside `expense_split/`: `firestore.rules`, `firestore.indexes.json`, `storage.rules`, `functions/` (TypeScript, Node 20), emulators.
- [x] `.firebaserc` with `default`/`staging`/`prod` aliases (all point at `equisplit-d4c74`).
- [x] Rewrite `web/firebase-messaging-sw.js` with the real web config from `lib/firebase_options.dart` and Firebase JS SDK 13.1.0 compat imports (matches `firebase_core_web` 4.x).

**Exit:** emulator suite boots; a throwaway screen can sign in and write a document.

### Phase 1 — Schema, rules, indexes (~1.5–2 days)

Create:

```
firestore.rules
firestore.indexes.json
storage.rules
functions/
  package.json
  tsconfig.json
  src/index.ts
  src/auth.ts
  src/groups.ts
  src/expenses.ts
  src/notifications.ts
  src/cleanup.ts
  src/lib/firestore.ts      # batched delete, converters, constants
  src/lib/fcm.ts
test/                        # rules tests, if using @firebase/rules-unit-testing
```

Implement exactly the schema in `decisions.md` §3. Do not add fields "for later".

**Rules requirements** (each must have a deny test):

- `users/{uid}`: read/write self only. `isPremium`, `premiumUntil` are **client-write-denied** (Admin SDK only). `devices/**` self only.
- `groups/{gid}`: list requires `memberUids array-contains request.auth.uid`; the query **must** include that filter. Create only with `ownerUid == request.auth.uid` and `request.auth.uid in memberUids`. Update/delete owner-only.
- `groups/{gid}/members/{memberId}`: read by members; placeholder create by members; update self (`name`, `avatarUrl`, `hasFcmToken`) or admin; `isRemoved` / delete admin or owner only.
- `groups/{gid}/expenses/{expenseId}`: read/create by members; update/delete by creator, group admin, or owner. Validate `amount > 0`, non-empty `description`, non-empty `splits`, and that `memberIds` includes the payer/splits/payments members.
- `groups/{gid}/categories/{categoryId}`: read by members; create requires premium; delete admin-only.
- `invites/{token}`: **no client read or write** (callables only).
- `cashInflows/{id}`: owner-only (`resource.data.uid == request.auth.uid`).
- `storage.rules`: `avatars/{uid}/**` owner write, `image/*`, ≤ 5 MB; read by authenticated users.

Add the composite indexes from `decisions.md` §3 now; Firestore will surface any extra ones during Phase 3 — add them to `firestore.indexes.json` in one pass.

**Exit:** rules emulator tests cover every deny path; indexes deploy cleanly.

### Phase 2 — Cloud Functions (~3–4 days)

TypeScript, gen 2, same region as Firestore. Implement the inventory in `decisions.md` §4. Behaviour contract:

| Function | Notes |
|---|---|
| `bootstrapUser` | Idempotent. On `users/{uid}` create: personal group (`type: PERSONAL`), owner member doc keyed by `uid`, 9 default categories, then set `personalGroupId`. Must not fail if it runs twice. |
| `onGroupCreated` | Seed the nine default categories for every new group (regular and personal) so non-premium users never write categories. |
| `createInvite` | Callable. Caller must be a group member (the UI exposes Invite to any member; admins are a superset). Token = 32+ random bytes, URL-safe. 7-day expiry. Returns `{ token, url }` where `url` is built from the `INVITE_BASE_URL` param. Rejects members who are already linked or removed. |
| `claimInvite` | Callable + transaction. Reject used/expired tokens and users already in the group. Set `uid`, copy `name`/`avatarUrl`/`email` onto the member doc, append uid to `memberUids`, delete the invite. Never rewrite expenses. |
| `onExpenseCreated` | Firestore trigger on `groups/{gid}/expenses/{eid}`. Notify all other member uids with device tokens. Payload keys must stay compatible with `NotificationService`: `type`, `group_id`, `expense_id`, `sender_id`, `amount` (string values). Update `lastActivityAt`. |
| `sendSettlementReminder` | Callable. Verify both users share a group; rate-limit 1 per pair per day using `reminders/{from}_{to}_{yyyyMMdd}`; send FCM to the target's devices. |
| `sendTestNotification` | Callable. Self-only debug ping. |
| `removeMember` | Callable. Admin/owner only. Set `isRemoved: true`, remove uid from `memberUids`. Do not delete the doc. |
| `deleteGroup` | Callable. Owner only. Batched recursive delete of `members`, `expenses`, `categories`, then the group doc. |
| `resetPersonalBalance` | Callable. Delete the caller's personal-group expenses and own cash inflows. |
| `onUserDelete` | Auth `onDelete` (v1 trigger). Delete profile/devices + personal group; anonymise member docs (clear `uid`, `name` → "Removed user", keep expenses valid). |
| `cleanupInvites` | Scheduled daily 03:00. Delete expired/used invites. |
| `syncMemberProfile` | On user update, propagate `name`/`avatarUrl` to member docs. Required: clients cannot write cross-group members. |
| `onDeviceRegistered` / `onDeviceRemoved` | Maintain `hasFcmToken` on member docs (clients cannot write cross-group members). |
| `createCategory` | **Not implemented.** Custom-category creation is a client write gated by premium in rules + a client uniqueness check (D27). |

All functions are deployed to `europe-west1` with `setGlobalOptions({ region, maxInstances: 10, memory: '256MiB', timeoutSeconds: 60 })`. `firebase-admin ^13.5.0` + `firebase-functions ^6.6.0` are used because admin v14 requires Node 22 while the runtime is Node 20.

**Exit:** emulator integration test passes signup → personal group → invite → claim → expense → settle → reminder; a real device receives foreground and background pushes.

### Phase 3 — Flutter data layer (~7–9 days)

#### 3.1 Dependencies

Upgrade **all** `firebase_*` together before anything else — `firebase_auth ^7`, `cloud_firestore ^7`, `firebase_storage ^14` require `firebase_core ^5.1.0`, while the repo is on `3.10.1`.

```bash
flutter pub upgrade --major-versions
flutterfire configure --project=equisplit-d4c74 \
  --platforms=android,ios,web,macos,windows
```

- Keep `firebase_messaging`, `google_sign_in`, `google_sign_in_web` on versions compatible with `firebase_core` 5.x.
- Remove: `pusher_channels_flutter`, `web_socket_channel`, `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `path_provider`, `path`, `rxdart`, `go_router`, `flutter_secure_storage`, `uuid`, `shared_preferences`.
- `http` is **kept**: `profile_screen.dart` calls `http.head(uri)` to validate a pasted avatar URL. Do not remove the dependency without deleting that dialog.
- Delete `web/drift_worker.js`, `web/drift_worker_placeholder.js`, `web/sqlite3.wasm`.
- Auth no longer persists anything locally, so `shared_preferences` is gone.
- `go_router` was declared but unused; navigation is `Navigator`/`MaterialApp.home`.

#### 3.2 New core layer

```
lib/src/core/firebase/
  firebase_bootstrap.dart      # init + emulator connect + App Check
  firestore_refs.dart          # typed CollectionReference/DocumentReference helpers
  firestore_converters.dart    # Timestamp <-> DateTime, num -> double, string id helpers
  firebase_error_mapper.dart   # FirebaseAuthException / FirebaseException -> user text
```

Wire `firebase_bootstrap.dart` from `main.dart`; keep `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.

Delete `lib/src/shared/data/api_client.dart` and `lib/src/config/environment.dart`.

#### 3.3 Auth

Rewrite `lib/src/features/auth/data/auth_repository.dart` against `FirebaseAuth`, keeping `AuthController`'s public API (`login`, `register`, `signInWithGoogle`, `updateProfile`, `reloadUser`/`refreshUser`, `requestVerification`, `uploadAvatar`, `logout`, `forgotPassword`) so screens change minimally.

- Session: `authStateChanges()` + `users/{uid}` snapshot stream → `User`. Delete all `SharedPreferences` session/token code.
- Register: `createUserWithEmailAndPassword` → `updateDisplayName` → write `users/{uid}` → send verification email. `bootstrapUser` creates the personal group, so do **not** create it client-side.
- Login: `signInWithEmailAndPassword`. **Remove `checkEmail`** entirely (repo + controller + login screen step). Map `user-not-found` → "No account found — create one"; `wrong-password`/`invalid-credential` → invalid credentials.
- Google: mobile `GoogleSignIn.instance.authenticate()` → `GoogleAuthProvider.credential(idToken, accessToken)` → `signInWithCredential`. Web: keep the existing `authenticationEvents` listener or switch to `signInWithPopup`; whichever you choose, update `google_sign_in_button*.dart` consistently.
- Forgot password: `sendPasswordResetEmail`.
- Verification: `user.emailVerified` + `sendEmailVerification`; profile badge reads `emailVerified`.
- Password change: if `hasPassword`, `reauthenticateWithCredential(EmailAuthProvider.credential(email, current))` then `updatePassword`; Google-only users use `linkWithCredential(EmailAuthProvider.credential(email, newPass))`.
- Avatar: `FirebaseStorage.instance.ref('avatars/$uid/profile.jpg')` → `putData`/`putFile` → `getDownloadURL()` → update `users/{uid}.avatarUrl`.
- Logout: delete the device token doc, then `signOut()`.
- Invite link: keep `AuthGate`'s `?token=` handling but call the `claimInvite` **callable** instead of the repository HTTP method; change the `userId` parameter to `String`.
- FCM: upsert `users/{uid}/devices/{tokenId}` = `{token, platform, updatedAt}`; set `hasFcmToken: true` on the user's member docs.

`User` model: `String id`, drop `balance`, keep `isVerified` (map from `emailVerified`), `hasPassword`, `isPremium`, `personalGroupId`.

#### 3.4 Models → `String`

| File | Changes |
|---|---|
| `auth/domain/user_model.dart` | `String id`; remove `balance`; add `personalGroupId`; `fromDoc`/`toMap` |
| `groups/domain/group_model.dart` | `String id`; add `ownerUid`, `memberUids`, `lastActivityAt`; `type` enum-ish string unchanged |
| `people/domain/member_model.dart` | `String id`, `String groupId`, `String? userId`; `isAdmin` → `bool` (keep a getter if UI compares to `1`) |
| `expenses/domain/expense_model.dart` | `String id/groupId/payerId`, `String? groupId`; `ExpenseSplit.id`/`ExpensePayment.id` → `String?` (embedded entries may have no id); add `payerName`, `memberIds` |
| `categories/domain/category_model.dart` | `String id`, `String? groupId` |
| `cash_inflows/domain/cash_inflow_model.dart` | `String id`, `String userId`, `String? expenseId` |
| `expenses/domain/balance_calculator.dart` | `Map<String,double>`, `DebtNode.memberId` `String`, `BalanceTransfer.fromMemberId/toMemberId` `String`. Logic unchanged. |

Add `fromDoc(DocumentSnapshot<Map<String,dynamic>>)` and `toMap()` to each entity. Read `Timestamp` via a shared converter; tolerate `null` dates by falling back to `createdAt`/now.

#### 3.5 Repositories, providers, real-time

Keep class names, provider names, and method names; change signatures to `String` and internals to Firestore.

| File | Required work |
|---|---|
| `groups/data/groups_repository.dart` | `watchGroups()` via `memberUids array-contains uid` + `createdAt desc`; create = batch(group + owner member + categories) or rely on `bootstrapUser` for personal; update/delete; `generateInvite`/`claimInvite` → callables; `resetPersonalBalance` → callable or batch delete (Open Decision 2); delete `syncPersonalFromExpenses` |
| `groups/data/groups_repository.dart` providers | `groupsListProvider` → `StreamProvider`/`AsyncNotifier` backed by snapshot; `groupMembersProvider(gid)` and `allMembersFutureProvider(gid)` → stream/listen; `int` → `String` family args |
| `people/data/members_repository.dart` | `watchMembers(gid)`, add placeholder (`addDoc`), update, remove via callable; reminders via callable; `int` → `String` |
| `expenses/data/expenses_repository.dart` | `watchExpenses(gid, dateRange, memberId)` with `where('date', ...)` + optional `memberIds array-contains`; batched create/update/delete; compute `memberIds` and `payerName` on write; `int` → `String` |
| `categories/data/categories_repository.dart` | `watchCategories(gid)`, create (premium check + duplicate-name check), delete (block if used). Keep `groupCategoriesProvider` name |
| `cash_inflows/data/cash_inflow_repository.dart` | `watchInflows(uid, range)`; keep `groupId` parameter in the provider signature for UI compatibility but ignore it in the query (matches current backend); CRUD |
| `expenses/presentation/expenses_providers.dart` | `int?` → `String?` for `expenseUserFilterProvider`; `String` family keys for date/minimize/inflows; add `personalBalanceProvider` |

Rules for real-time:

- Prefer `StreamProvider`/`StreamNotifier` over `FutureProvider` for Firestore reads. Remove manual `ref.refresh`/`ref.invalidate` after writes where the listener already updates.
- `expensesFutureProvider` stays an `AsyncNotifierProvider.autoDispose` if screens call `.notifier` methods, but `build()` should subscribe to a snapshot and expose the latest list.
- Add a derived `personalBalanceProvider = totalInflows − totalPersonalExpenses` and remove `User.balance` reads plus the `reloadUser()` calls that exist only to refresh balance (`expenses_list_screen.dart`, `add_expense_screen.dart`, `settle_up_screen.dart`, `payments_list_screen.dart`, `profile_screen.dart`).
- Resolve the personal group from `users/{uid}.personalGroupId`, not by scanning the group list.

#### 3.6 String-ID presentation sweep

These files contain `int` IDs or parse them. Fix every one; do not leave `int.parse` on Firestore IDs.

```
lib/src/shared/presentation/widgets/filter_modal.dart
lib/src/features/analytics/presentation/stats_screen.dart        # List<int> groupIds + int.parse(groupIdsString)
lib/src/features/analytics/presentation/group_stats_screen.dart  # <int,double> payerMap
lib/src/features/analytics/presentation/global_settlements_screen.dart
lib/src/features/categories/presentation/category_management_screen.dart
lib/src/features/expenses/presentation/add_expense_screen.dart   # Map<int,...>, Set<int>
lib/src/features/expenses/presentation/balances_screen.dart
lib/src/features/expenses/presentation/expenses_list_screen.dart
lib/src/features/expenses/presentation/payments_list_screen.dart
lib/src/features/expenses/presentation/settle_up_screen.dart
lib/src/features/groups/presentation/group_detail_screen.dart
lib/src/features/groups/presentation/group_settings_screen.dart
lib/src/features/groups/presentation/groups_list_screen.dart
lib/src/features/groups/presentation/join_group_dialog.dart
lib/src/features/home/presentation/main_screen.dart
lib/src/features/people/presentation/member_profile_screen.dart
lib/src/features/people/presentation/members_list_view.dart
lib/src/features/auth/presentation/auth_gate.dart
lib/src/features/auth/presentation/profile_screen.dart
```

Also check `stats_screen.dart`: the group-ID list is currently comma-joined into a string and `int.parse`d back. Keep the comma-join only if it stays `String`-safe; otherwise pass `List<String>` directly.

#### 3.7 Platform cleanup

- Delete `linux/`; remove the Linux row from `README.md`; remove `PlatformInfo.isLinux` usage if it becomes dead.
- Android: confirm `google-services.json`, minSdk (Flutter default is fine for current FlutterFire; bump to 23 if Gradle complains).
- iOS/macOS: network client entitlements (already present), keychain sharing if needed, APNs key uploaded to Firebase, `GoogleService-Info.plist` in both targets.
- Windows: verify `firebase_core`/`firebase_auth`/`cloud_firestore`/`firebase_storage` desktop support compiles; `flutter_local_notifications` has no Windows implementation — guard the notification init so Windows/macOS don't crash.
- Web: real config in `firebase-messaging-sw.js`, authorized domain, popup sign-in, `flutter build web`.

#### 3.8 Verification

- `flutter analyze` → zero issues (fix pre-existing warnings you touch, e.g. the duplicated `@override` in `AuthGate`).
- `dart format lib test`.
- Add the repo's first tests: model `fromDoc`/`toMap`, `BalanceCalculator` with `String` IDs (direct + minimized + multi-payer + settlement), `personalBalanceProvider` arithmetic, error mapping.
- Emulator-backed integration test for the golden path.

### Phase 4 — Parity QA (~4–5 days)

Run the checklist on **Android, iOS, Web, macOS, Windows**:

- [ ] Sign up → verification email → personal group + 9 default categories exist (`General`, `Food & Drinks`, `Transportation`, `Entertainment`, `Shopping`, `Utilities`, `Housing`, `Life`, `Other`).
- [ ] Google sign-in: new user, returning user, existing-email linking.
- [ ] Forgot password; change password with and without an existing password.
- [ ] Create/rename/delete group; duplicate-name handling; leave/remove member.
- [ ] Invite → open `/join?token=` on a second account → claim; already-member, expired, used, and bad-token errors.
- [ ] Add expense: equal split, custom split, multi-payer, settlement; edit/delete; date/member filters.
- [ ] Balances: minimize vs direct debts; settle-up writes the correct entries.
- [ ] Monthly stats, category breakdown, global settlements, cash inflows.
- [ ] Personal balance = inflows − personal expenses; premium lock on personal group and custom categories.
- [ ] Avatar upload on all platforms.
- [ ] Push: expense added, settlement reminder; foreground/background/terminated; web push.
- [ ] Offline: airplane mode → add expense → reconnect → syncs.
- [ ] Rules denials verified from a second account (not just unit tests).

**Exit:** no regressions vs current Laravel behaviour, rules tests green, no P1 bugs.

### Phase 5 — Decommission (~1–2 days)

- Archive `equisplit/` (tag it; do not delete history).
- Remove staging API, Soketi, DB, Redis, Cloudinary credentials; rotate the Firebase service account Laravel used.
- Update `README.md`: Firebase setup, emulator instructions, deploy commands, platform matrix without Linux.
- Update `.agent/workflows/run-*.md`: drop `php artisan serve` and `10.0.2.2:8000`; document `firebase emulators:start`.
- CI: `flutter analyze`, `flutter test`, rules tests via `firebase emulators:exec`, deploy rules/indexes/storage/functions on tags.
- Optional: enforce App Check, enable Firestore backups/PITR, add Crashlytics.

---

## 5. Field mapping (Laravel → Firestore)

Use this when translating repositories. Field names on the wire change from `snake_case` to the Firestore names in `decisions.md` §3.

| Laravel / current Dart | Firestore |
|---|---|
| `user.id` | `users/{uid}` doc ID + `uid` |
| `default_currency` | `defaultCurrency` |
| `avatar_url` | `avatarUrl` |
| `is_active_premium` | `isPremium` |
| `is_verified` | `emailVerified` (Auth) |
| `user.balance` | *removed* — derive |
| `group.id` | `groups/{gid}` doc ID |
| `group.type` | `type` (`REGULAR`/`PERSONAL`) |
| `group.created_at` | `createdAt` (`Timestamp`) |
| `member.id` | `groups/{gid}/members/{memberId}` doc ID |
| `member.group_id` | parent group (not stored) |
| `member.user_id` | `uid` |
| `member.is_admin` (int) | `isAdmin` (bool) |
| `expense.id` | `groups/{gid}/expenses/{expenseId}` doc ID |
| `expense.group_id` | parent group (not stored) |
| `expense.payer_id` | `payerId` |
| `expense.currency_code` | `currencyCode` |
| `expense.is_settlement` | `isSettlement` |
| `expense.payer` (nested member) | `payerName` snapshot |
| `split.id` | `splits[].memberId` + `amount` (no synthetic id needed) |
| `payment.id` | `payments[].memberId` + `amount` |
| `category.id` | `groups/{gid}/categories/{categoryId}` doc ID |
| `category.group_id` | parent group (not stored) |
| `cash_inflow.id` | `cashInflows/{inflowId}` doc ID |
| `cash_inflow.user_id` | `uid` |
| `cash_inflow.expense_id` | `expenseId` |

**Timestamps:** write `FieldValue.serverTimestamp()` for `createdAt`/`updatedAt`; for domain dates (`expense.date`, `inflow.date`) use `Timestamp.fromDate(date)`. Convert back with `.toDate()` and handle `null`.

**Push payloads:** keep keys `type`, `group_id`, `expense_id`, `sender_id`, `amount` as **strings** so existing `NotificationService` handling keeps working. Add new keys rather than renaming.

---

## 6. Provider inventory (keep these names)

| Provider | File | Target type |
|---|---|---|
| `authRepositoryProvider` | `features/auth/data/auth_repository.dart` | `Provider<AuthRepository>` (Firebase) |
| `authControllerProvider` | same | `StateNotifierProvider<AuthController, AsyncValue<User?>>` |
| `groupsRepositoryProvider` | `features/groups/data/groups_repository.dart` | `Provider<GroupsRepository>` |
| `groupsListProvider` | same | `StreamProvider`/`AutoDisposeStreamNotifier<List<Group>>` |
| `groupMembersProvider` | same | `StreamProvider.family<List<Member>, String>` |
| `allMembersFutureProvider` | same | `StreamProvider.family<List<Member>, String>` (name kept for UI) |
| `membersRepositoryProvider` | `features/people/data/members_repository.dart` | `Provider<MembersRepository>` |
| `membersFutureProvider` | same | `AsyncNotifierProvider.autoDispose.family<..., List<Member>, String>` |
| `expensesRepositoryProvider` | `features/expenses/data/expenses_repository.dart` | `Provider<ExpensesRepository>` |
| `expensesFutureProvider` | same | `AsyncNotifierProvider.autoDispose.family<..., List<Expense>, String>` |
| `unfilteredExpensesFutureProvider` | `features/expenses/presentation/expenses_providers.dart` | same, unfiltered |
| `expenseDateRangeFilterProvider` | same | `StateProvider.family<DateTimeRange?, String>` |
| `expenseUserFilterProvider` | same | `StateProvider.family<String?, String>` |
| `minimizeDebtsProvider` | same | `StateProvider.family<bool, String>` |
| `inflowsListProvider` | same | `StreamProvider.family<List<CashInflow>, String>` |
| `categoriesRepositoryProvider` | `features/categories/data/categories_repository.dart` | `Provider<CategoriesRepository>` |
| `groupCategoriesProvider` | same | `StreamProvider.family<List<Category>, String>` |
| `cashInflowRepositoryProvider` | `features/cash_inflows/data/cash_inflow_repository.dart` | `Provider<CashInflowRepository>` |
| `notificationServiceProvider` | `shared/services/notification_service.dart` | `Provider<NotificationService>` |

New providers allowed: `firebaseAuthProvider`, `firestoreProvider`, `firebaseStorageProvider`, `personalGroupProvider`, `personalBalanceProvider`, `firebaseFunctionsProvider`.

---

## 7. Security rules: what must be denied

Write these as tests before implementation. Any "allowed" test needs a deny counterpart.

1. Signed-out read of any group, expense, inflow, or category.
2. Signed-in non-member list/read of a group and its subcollections.
3. Member updating group name/owner/deleting the group.
4. Member setting `isPremium`/`premiumUntil` on their own user doc.
5. User reading/writing another user's `devices/**` or profile.
6. Non-premium creating a custom category.
7. Non-admin deleting a category or removing a member.
8. Any client reading or writing `invites/**`.
9. User reading another user's `cashInflows`.
10. Expense create/update that references a member not in the group, has `amount <= 0`, or has empty `splits`/`description`.
11. Avatar upload of a non-image or > 5 MB, or writing under another uid's prefix.

Rules `get()`/`exists()` calls are billed reads; do not nest them. Group listing must rely on `memberUids array-contains` alone.

---

## 8. Testing

Three layers of automated tests exist:

| Layer | Location | Command |
|---|---|---|
| Dart unit | `test/` (33 tests) | `flutter test` |
| Firestore/Storage rules | `functions/test/rules.test.js` (36 tests) | `firebase emulators:exec --only firestore,storage "npm --prefix functions test"` |
| Golden path (rules + functions) | `functions/test/integration/golden_path.test.js` | `firebase emulators:exec --only auth,firestore,functions "npm --prefix functions run test:integration"` |

The emulator suites need **JDK 21+** (firebase-tools refuses older runtimes). If your system JDK is 17, point `JAVA_HOME` at a 21 install for the command.

```bash
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test
npm --prefix functions run lint
```

The golden-path test signs up three users through the Auth emulator, writes Firestore documents over REST (so the real rules apply), and calls the deployed callables. It asserts the personal group + 9 categories, invite creation/claim, expense rules, `lastActivityAt`, reminder guards, `resetPersonalBalance`, `removeMember`, and `deleteGroup`. Extend it rather than adding another harness.

---

## 9. Pitfalls specific to this repo

**Resolved during Phases 3.1–3.7** (kept only as regression notes): FlutterFire version skew, fake `firebase-messaging-sw.js` config, duplicated `@override`/`int` invite claims in `AuthGate`, `stats_screen.dart` comma-joined `int` group IDs, integer `Member.isAdmin`, `Expense.payer` nested member reads, `environment.dart`/`api_client.dart`, balance-driven `reloadUser()` calls, unguarded `NotificationService.init()` on desktop, old `google_sign_in` API, `shared_preferences` session storage, `users.balance` reads, and the two-step email-existence login.

Still relevant:

1. **`http` stays** because `profile_screen.dart` uses `http.head` to validate a pasted avatar URL. Removing the dependency breaks that dialog.
2. **`Firebase.initializeApp` lives in `firebase_bootstrap.dart`** (called from `main.dart`) with `DefaultFirebaseOptions`. Do not initialise a second app or bypass the bootstrap, which also wires emulators/App Check.
3. **Invite deep links** on mobile are not wired (no Universal Links/App Links). Do not add Dynamic Links. Web works via `Uri.base`; mobile can be added later.
4. **ID equality in `BalanceCalculator`** works with `String`, but empty/missing member IDs collapse entries; validate `memberIds` before calling.
5. **Rules query coupling:** any `groups` query must include `where('memberUids', arrayContains: uid)` or rules will reject it — even an unfiltered `getGroups()`.
6. **No unique constraints:** duplicate group/category names are checked client-side; Firestore accepts duplicates.
7. **`Timestamp` vs `DateTime` in filters:** Firestore range filters require `Timestamp`, not `DateTime`. Convert in `where()` calls.
8. **`groupMembersProvider` vs `allMembersFutureProvider`** differ only by whether removed members are included (`includeDeleted`). Always write `isRemoved: false` when creating a member doc, or the equality filter silently omits it.
9. **Cross-group writes are denied.** `hasFcmToken` and profile propagation must stay in the Functions (`onDeviceRegistered`, `onDeviceRemoved`, `syncMemberProfile`); do not try to re-add client collection-group writes.
10. **`users/{uid}.uid` must equal the doc ID.** Rules create/update checks require it; a user document without `uid` is write-rejected.
11. **`isPremium` / `premiumUntil` are Admin-SDK-only.** Any client edit to those keys fails the update rule.
12. **Category seed list is duplicated** in `lib/src/core/constants/default_categories.dart` and `functions/src/lib/constants.ts`. Change both together.
13. **FCM registrations are Firebase Installation IDs** in `firebase_messaging` 17 (`register()` + `onRegistered`), not the old token strings. Device docs are keyed by a sanitised FID.

---

## 10. Conventions

- **Dart:** follow `analysis_options.yaml` (`flutter_lints`). `dart format` before commit. Prefer `const`, early returns, and explicit types on public APIs. Keep existing naming style.
- **Null safety:** no `!` on Firestore reads; use `??` defaults and tolerant converters.
- **Errors:** map Firebase errors to user-facing text in `firebase_error_mapper.dart`; surface via `GlobalErrorHandler`/SnackBars, never raw exception strings.
- **Functions:** TypeScript `strict`; one module per domain; shared helpers in `functions/src/lib/`; no `any` in exported signatures.
- **Commits:** conventional prefixes (`feat:`, `fix:`, `chore:`, `docs:`, `test:`). Reference the phase in the body, e.g. `Phase 3.5`.
- **Branches:** one per phase (`chore/firebase-upgrade`, `feat/firestore-schema`, `feat/auth-firebase`, `feat/data-layer`, `feat/parity-fixes`). Phase 3 may be one long-lived branch (`feat/firebase-backend`) if the app must stay shippable.
- **Docs:** any schema/rules/decision change updates `decisions.md` in the same PR. Update this file's checklists as phases complete.

---

## 11. Definition of done (per phase)

A phase is done only when all of these hold:

1. `flutter analyze` reports zero issues.
2. `dart format` is clean.
3. New unit/rules/function tests pass.
4. No `TODO`, `FIXME`, or commented-out Laravel code left in files you touched (use issue links instead).
5. `decisions.md` reflects any deviation.
6. The phase's exit criteria in §4 are demonstrably met (emulator or device evidence in the PR description).

---

## 12. Progress log

Update this table as work lands. Keep it short; details belong in PRs.

| Phase | Status | Notes |
|---|---|---|
| 0 — Firebase setup | Done | Real FCM service worker; emulator config in `firebase.json` |
| 1 — Schema/rules/indexes | Done | `firestore.rules`, `storage.rules`, `firestore.indexes.json`; 36 rules tests in `functions/test/rules.test.js` |
| 2 — Cloud Functions | Done | `functions/` builds; 15 functions; golden-path emulator test in `functions/test/integration/` |
| 3.1 — Dependencies | Done | FlutterFire family upgraded; Drift/Pusher/etc. removed; `http` kept for avatar URL check |
| 3.2 — Core Firebase layer | Done | bootstrap, refs, converters, error mapper |
| 3.3 — Auth | Done | Firebase Auth, Google, Storage avatars, callable invites; `checkEmail` removed |
| 3.4 — Models → String | Done | All IDs `String`; `fromMap`/`fromDoc` |
| 3.5 — Repositories/providers | Done | Firestore streams; derived `personalBalanceProvider` |
| 3.6 — String-ID UI sweep | Done | `flutter analyze` clean |
| 3.7 — Platform cleanup | Done | `linux/` deleted; desktop notification/ads/sign-in guards |
| 3.8 — Verification | Done | `flutter analyze` clean, 33 Dart tests, `flutter build web`, 36 rules tests, 8-step emulator golden path |
| 4 — Parity QA | Not started | Needs real devices for push, avatar, offline |
| 5 — Decommission | Not started | Archive Laravel (tag), don't delete history |
| 6 — Premium & backend parity | Done | D41 pricing/Play Billing (`features/premium/`, `verifyPremiumPurchase`), D42 admin notification callables; 56 Dart tests; emulator integration tests for D42 pending a JDK 21 install |

---

*Last updated: 2026-10-30. Authoritative decisions: [`decisions.md`](decisions.md).*
