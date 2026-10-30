---
description: Run the app on mobile (Android/iOS)
---

# Run on Mobile Platforms

This workflow runs EquiSplit on Android or iOS devices/emulators against Firebase.

## Prerequisites

### Android
- Flutter SDK with Android support
- Android Studio + SDK
- Emulator or physical device connected
- `android/app/google-services.json` (already committed)

### iOS
- Flutter SDK with iOS support (macOS only)
- Xcode + CocoaPods
- Simulator or physical device connected
- `ios/Runner/GoogleService-Info.plist` (already committed)

### Backend
There is **no local API server**. Use the Firebase emulators or the real project.

## Steps

1. **List available devices**:
```bash
flutter devices
```

2. **Get dependencies**:
```bash
flutter pub get
```

3. **Choose a backend**

   **A. Emulators:**
```bash
firebase emulators:start
```
   Then run with the flag:
```bash
# Android emulator
flutter run -d <android-device-id> --dart-define=USE_FIREBASE_EMULATORS=true

# iOS simulator
flutter run -d <ios-device-id> --dart-define=USE_FIREBASE_EMULATORS=true
```

   `firebase_bootstrap.dart` automatically uses `10.0.2.2` on Android and `localhost` on iOS.

   **B. Real Firebase project:**
```bash
flutter run -d <android-or-ios-device-id>
```

> Physical devices cannot reach `localhost` emulators. Either forward ports (`adb reverse`) or use the real project.

## Push notifications

- **Android** → `google-services.json` includes the sender ID; FCM registrations are written to `users/{uid}/devices/{fid}`.
- **iOS** → upload your APNs auth key in Firebase Console → Cloud Messaging, and enable the Push Notifications capability in Xcode. Simulators do not receive APNs pushes.

## Troubleshooting

### Android
- Emulator not starting → launch it from Android Studio first.
- `google-services.json` missing → `flutterfire configure --project=equisplit-d4c74`.
- Check logs with `adb logcat`.

### iOS
- CocoaPods fails → `pod install` in `ios/`.
- Signing issues → open `ios/Runner.xcworkspace` in Xcode and configure a team.
- Google sign-in fails → confirm the `REVERSED_CLIENT_ID` URL scheme is in `Info.plist`.
