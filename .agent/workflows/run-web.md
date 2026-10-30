---
description: Run the app on web (Chrome)
---

# Run on Web Platform

This workflow runs EquiSplit in Chrome against either the Firebase emulators or the real `equisplit-d4c74` project.

## Prerequisites

- Flutter SDK installed
- Chrome installed
- `firebase-tools` installed globally (`npm i -g firebase-tools`), for the emulator path

## Steps

1. **Clean the project** (optional, if you hit stale build issues):
```bash
flutter clean
```

2. **Get dependencies**:
```bash
flutter pub get
```

3. **Choose a backend**

   **A. Emulators (recommended while developing):**
```bash
firebase emulators:start
```
   In a second terminal:
```bash
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

   **B. Real Firebase project:**
```bash
flutter run -d chrome
```

The app opens in Chrome with hot reload enabled.

## Invite links

Web invites are `https://<host>/join?token=<token>`. In development use:

```
http://localhost:<port>/?token=<token>
```

`AuthGate` reads `Uri.base.queryParameters['token']` and calls the `claimInvite` callable.

## Troubleshooting

- **Chrome doesn't launch** → verify `flutter devices` lists `chrome`.
- **`auth/unauthorized-domain`** → add the origin in Firebase Auth → Settings → Authorized domains.
- **Firestore/Storage calls fail against emulators** → confirm `firebase emulators:start` is still running and the app was launched with `USE_FIREBASE_EMULATORS=true`.
- **Push notifications** → `web/firebase-messaging-sw.js` must be served from the site root; the VAPID key must match `NotificationService._vapidKey`.
