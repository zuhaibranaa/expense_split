---
description: Run the app on macOS
---

# Run on macOS Platform

This workflow runs EquiSplit as a native macOS application.

## Prerequisites

- Flutter SDK with macOS support enabled
- Xcode installed
- CocoaPods installed (`brew install cocoapods`)
- `firebase-tools` for the emulator path

## Steps

1. **Verify macOS support is enabled**:
```bash
flutter config --enable-macos-desktop
```

2. **Clean the project** (optional):
```bash
flutter clean
```

3. **Get dependencies**:
```bash
flutter pub get
```

4. **Choose a backend**

   **A. Emulators:**
```bash
firebase emulators:start
```
   In a second terminal:
```bash
flutter run -d macos --dart-define=USE_FIREBASE_EMULATORS=true
```

   **B. Real Firebase project:**
```bash
flutter run -d macos
```

The app launches as a native macOS application with hot reload.

> Google sign-in works on macOS. Ads and local notifications are disabled on desktop; FCM is not initialised there.

## Building for Release

```bash
flutter build macos --release
```

The app is written to `build/macos/Build/Products/Release/equisplit.app`.

## Troubleshooting

- **CocoaPods errors** → run `pod install` in the `macos` directory.
- **Signing issues** → configure a team and bundle ID in Xcode.
- **App doesn't launch** → check Console.app for crash logs.
- **Outbound network** → the macOS sandbox needs the client entitlements already present in `macos/Runner/*.entitlements`.
