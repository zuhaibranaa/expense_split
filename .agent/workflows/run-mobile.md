---
description: Run the app on mobile (Android/iOS)
---

# Run on Mobile Platforms

This workflow runs the SettleUp Clone app on Android or iOS devices/emulators.

## Prerequisites

### For Android:
- Flutter SDK installed with Android support
- Android Studio installed
- Android emulator or physical device connected

### For iOS:
- Flutter SDK installed with iOS support (macOS only)
- Xcode installed
- iOS simulator or physical device connected
- CocoaPods installed

## Backend Configuration

**Important**: Mobile devices cannot access `localhost` on your development machine directly.

### For Android Emulator:
The app automatically uses `http://10.0.2.2:8000` which maps to your host machine's localhost.

### For iOS Simulator:
The app uses `http://localhost:8000` which works on iOS simulator.

### For Physical Devices:
You'll need to modify the backend URL to use your computer's IP address:

1. Find your computer's IP address:
   - macOS: System Preferences → Network
   - Windows: `ipconfig`
   - Linux: `ifconfig` or `ip addr`

2. Temporarily modify `lib/src/shared/utils/platform_info.dart`:
   ```dart
   static String getDefaultApiBaseUrl() {
     // Replace with your computer's IP address
     return 'http://192.168.1.XXX:8000';
   }
   ```

3. Ensure your backend server is accessible from the network (not just localhost)

## Steps

1. **List available devices**:
```bash
flutter devices
```

2. **Get dependencies**:
// turbo
```bash
flutter pub get
```

3. **Run on Android**:
```bash
flutter run -d <android-device-id>
```

4. **Run on iOS** (macOS only):
```bash
flutter run -d <ios-device-id>
```

## Troubleshooting

### Android:
- If the emulator doesn't start, launch it from Android Studio first
- For API connectivity issues, verify the backend is running and accessible
- Check `adb logcat` for detailed error logs

### iOS:
- If CocoaPods fails, run `pod install` in the `ios` directory
- For signing issues, open `ios/Runner.xcworkspace` in Xcode and configure signing
- Check Xcode console for detailed error logs
