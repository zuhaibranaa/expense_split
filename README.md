# SettleUp Clone

A cross-platform expense splitting and group management application built with Flutter. Split bills, track expenses, and manage group finances across all your devices.

## ✨ Features

- **Group Management**: Create and manage groups for different occasions (trips, roommates, events)
- **Expense Tracking**: Add and split expenses among group members
- **Balance Calculation**: Automatically calculate who owes whom
- **Settlement Tracking**: Record payments and settle debts
- **Analytics**: View spending statistics and trends
- **Offline-First**: Works offline with local database sync

## 🚀 Platform Support

This app runs on **all major platforms**:

| Platform | Status | Notes |
|----------|--------|-------|
| 🌐 Web | ✅ Supported | Runs in Chrome, Firefox, Safari, Edge |
| 🍎 macOS | ✅ Supported | Native macOS application |
| 🪟 Windows | ✅ Supported | Native Windows application |
| 🐧 Linux | ✅ Supported | Native Linux application |
| 🤖 Android | ✅ Supported | Android 5.0+ (API 21+) |
| 📱 iOS | ✅ Supported | iOS 12.0+ |

## 📋 Prerequisites

- **Flutter SDK** 3.10.0 or higher
- **Dart** 3.10.0 or higher

### Platform-Specific Requirements

- **macOS/iOS**: Xcode and CocoaPods
- **Android**: Android Studio and Android SDK
- **Windows**: Visual Studio 2022 with C++ desktop development
- **Linux**: Required development libraries (see [Flutter Linux setup](https://docs.flutter.dev/get-started/install/linux))

## 🛠️ Getting Started

### 1. Clone and Setup

```bash
# Clone the repository
git clone <repository-url>
cd settle_up_clone

# Get dependencies
flutter pub get
```

### 2. Run on Your Platform

#### Web
```bash
flutter run -d chrome
```
Or use the workflow: `/run-web`

#### macOS
```bash
flutter run -d macos
```
Or use the workflow: `/run-macos`

#### Mobile (Android/iOS)
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```
Or use the workflow: `/run-mobile`

#### Windows
```bash
flutter run -d windows
```

#### Linux
```bash
flutter run -d linux
```

## 🔧 Backend Configuration

The app includes an optional backend API client for synchronization features.

### Default Configuration

The app automatically detects your platform and uses the appropriate backend URL:

- **Web & Desktop**: `http://localhost:8000`
- **Android Emulator**: `http://10.0.2.2:8000` (maps to host machine's localhost)
- **iOS Simulator**: `http://localhost:8000`

### Physical Mobile Devices

For physical Android/iOS devices, you'll need to configure your computer's IP address:

1. Find your computer's IP address on the local network
2. Update `lib/src/shared/utils/platform_info.dart` with your IP
3. Ensure your backend server accepts connections from the network (not just localhost)

See `/run-mobile` workflow for detailed instructions.

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/platform_info_test.dart

# Run with coverage
flutter test --coverage
```

## 🏗️ Building for Production

### Web
```bash
flutter build web --release
# Output: build/web/
```

### macOS
```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/
```

### Android
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS
```bash
flutter build ios --release
# Requires Xcode for final app signing
```

### Windows
```bash
flutter build windows --release
# Output: build/windows/runner/Release/
```

### Linux
```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

## 📦 Tech Stack

- **Framework**: Flutter 3.38.1
- **State Management**: Riverpod
- **Routing**: GoRouter
- **Database**: Drift (SQLite) with web support
- **HTTP Client**: http package
- **Charts**: FL Chart
- **Fonts**: Google Fonts

## 🗂️ Project Structure

```
lib/
├── main.dart                 # App entry point
├── src/
│   ├── app.dart             # App configuration
│   ├── features/            # Feature modules
│   │   ├── auth/           # Authentication
│   │   ├── groups/         # Group management
│   │   ├── expenses/       # Expense tracking
│   │   ├── people/         # Member management
│   │   └── analytics/      # Statistics
│   └── shared/             # Shared utilities
│       ├── data/           # API client, repositories
│       ├── presentation/   # Themes, widgets
│       └── utils/          # Platform detection, helpers
```

## 🔍 Troubleshooting

### Web Platform
- **Database errors**: Check browser console for WASM loading issues
- **CORS errors**: Ensure backend has proper CORS configuration

### macOS/iOS
- **CocoaPods errors**: Run `pod install` in the platform directory
- **Signing issues**: Configure signing in Xcode

### Android
- **Emulator not found**: Launch emulator from Android Studio first
- **API connection fails**: Verify backend is running on port 8000

### General
- **Build errors**: Try `flutter clean && flutter pub get`
- **Platform not available**: Run `flutter doctor` to check setup

## 📚 Workflows

This project includes helpful workflows for common tasks:

- `/run-web` - Run on web platform
- `/run-macos` - Run on macOS
- `/run-mobile` - Run on mobile platforms

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `flutter test`
5. Submit a pull request

## 📄 License

This project is for educational purposes.

## 🔗 Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Drift Documentation](https://drift.simonbinder.eu/)
- [Riverpod Documentation](https://riverpod.dev/)
