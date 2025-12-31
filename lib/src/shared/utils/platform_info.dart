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
}
