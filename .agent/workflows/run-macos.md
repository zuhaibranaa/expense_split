---
description: Run the app on macOS
---

# Run on macOS Platform

This workflow runs the SettleUp Clone app as a native macOS application.

## Prerequisites

- Flutter SDK installed with macOS support enabled
- Xcode installed (for macOS development)
- CocoaPods installed (run `brew install cocoapods` if not installed)
- Backend server running on `http://localhost:8000` (optional, for API features)

## Steps

1. **Verify macOS support is enabled**:
```bash
flutter config --enable-macos-desktop
```

2. **Clean the project** (optional, but recommended if you encounter issues):
```bash
flutter clean
```

3. **Get dependencies**:
// turbo
```bash
flutter pub get
```

4. **Run the app on macOS**:
// turbo
```bash
flutter run -d macos
```

The app will launch as a native macOS application with hot reload enabled.

## Building for Release

To create a release build:
```bash
flutter build macos --release
```

The built app will be located at `build/macos/Build/Products/Release/settle_up_clone.app`

## Troubleshooting

- If you get CocoaPods errors, run `pod install` in the `macos` directory
- For signing issues, check Xcode signing settings
- If the app doesn't launch, check Console.app for crash logs
