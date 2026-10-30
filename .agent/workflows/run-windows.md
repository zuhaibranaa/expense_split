---
description: Run the app on Windows
---

# Run on Windows Platform

This workflow runs EquiSplit as a native Windows application.

## Prerequisites

- Flutter SDK with Windows desktop support
- Visual Studio 2022 with the **Desktop development with C++** workload
- `firebase-tools` for the emulator path

## Steps

1. **Verify Windows support is enabled**:
```bash
flutter config --enable-windows-desktop
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
   In a second terminal:
```bash
flutter run -d windows --dart-define=USE_FIREBASE_EMULATORS=true
```

   **B. Real Firebase project:**
```bash
flutter run -d windows
```

> Windows uses the `windows` entry in `lib/firebase_options.dart` (a web-style app registration). Google sign-in, ads, local notifications and FCM are not initialised on Windows; the app degrades gracefully.

## Building for Release

```bash
flutter build windows --release
```

The bundle is written to `build/windows/x64/runner/Release/`.

## Troubleshooting

- **CMake/Visual Studio errors** → install the C++ desktop workload and re-run `flutter doctor`.
- **App can't reach Firebase** → check the Windows firewall allows outbound 443.
- **Crash on startup** → run from a terminal to capture the Dart stack trace.
