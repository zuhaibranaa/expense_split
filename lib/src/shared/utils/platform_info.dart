import 'package:flutter/foundation.dart';

/// Utility class for platform detection that works across all Flutter platforms.
/// 
/// This class provides safe platform checks that work on web, mobile, and desktop.
/// Uses Flutter's foundation library to avoid importing dart:io which breaks web builds.
class PlatformInfo {
  /// Returns true if running on web platform
  static bool get isWeb => kIsWeb;

  /// Returns true if running on mobile (Android or iOS)
  static bool get isMobile => !kIsWeb && (isAndroid || isIOS);

  /// Returns true if running on desktop (macOS, Windows, or Linux)
  static bool get isDesktop => !kIsWeb && (isMacOS || isWindows || isLinux);

  /// Returns true if running on Android
  static bool get isAndroid {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Returns true if running on iOS
  static bool get isIOS {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// Returns true if running on macOS
  static bool get isMacOS {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Returns true if running on Windows
  static bool get isWindows {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.windows;
  }

  /// Returns true if running on Linux
  static bool get isLinux {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Returns a human-readable platform name for debugging/analytics
  static String get platformName {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  /// Returns the appropriate API base URL for the current platform
  /// 
  /// - Web & Desktop: http://localhost:8000
  /// - Android: http://10.0.2.2:8000 (emulator localhost)
  /// - iOS: http://localhost:8000 (simulator can use localhost)
  /// 
  /// Note: For physical devices, you'll need to configure the actual
  /// IP address of your backend server.
  static String getDefaultApiBaseUrl() {
    if (isWeb || isDesktop) {
      return 'http://localhost:8000';
    } else if (isAndroid || isIOS) {
      // Use local IP for physical devices and emulators
      // Replace with your machine's local IP
      return 'http://192.168.1.2:8000';
    }
    // Fallback
    return 'http://localhost:8000';
  }
}
