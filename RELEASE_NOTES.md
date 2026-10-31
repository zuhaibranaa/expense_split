# Release Notes — EquiSplit v1.1.0

## Highlights

- **Real-time expense updates** for all group members — expenses, balances, and member lists now refresh live via Firestore snapshots instead of manual reloads.
- **Balance auto-refreshes** when opening a group — no more stale totals after adding or editing an expense.
- **Categories moved to Group Settings** — category management lives where it belongs, next to the group it applies to.
- **Fixed income (cash inflow) entries being duplicated on update** — editing an inflow no longer creates a duplicate.
- **Stats screen now uses a flexible Date Range filter** — pick any start/end instead of a fixed month.
- **Consistent password validation** across sign-up and profile.
- **OAuth (Google) users can set a password** without entering a current one — linking a password to a Google-only account now works.
- **Bug fixes and performance improvements** throughout the data layer and UI.

## Under the hood

- Migrated the Android toolchain to Gradle 9.3.1 / AGP 9.1.0 / Kotlin 2.4.0.
- Premium pricing and Google Play Billing scaffold (monthly + yearly, 7-day trial) with a paywall screen.
- Admin notification senders ported from the Laravel backend.
- Personal expenses group is now provisioned and repaired automatically on the client (works on the free Spark plan).
- Avatar uploads moved to Cloudinary (free tier) so they work without Firebase Storage.
- Invite / category / member / group management work fully on the Spark (free) plan — no Cloud Functions required.
- 62 unit tests; `flutter analyze` clean.

## Known limitations

- Push notifications require a Blaze (paid) plan and are disabled on Spark.
- Premium purchases require Google Play Console product setup and a Play service account secret.
- Invite links on mobile are not deep-linked yet (web works via `?token=`).

---
*Released 2026-10-31 · tag `v1.1.0`*
