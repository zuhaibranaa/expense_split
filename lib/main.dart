import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'src/app.dart';
import 'src/core/firebase/firebase_bootstrap.dart';
import 'src/shared/services/notification_service.dart';

bool get _supportsMobileAds {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

bool get _supportsGoogleSignIn {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeFirebase();

  if (_supportsMobileAds) {
    MobileAds.instance.initialize();
  }

  // Initialize Google Sign In only where the plugin has an implementation.
  // serverClientId (Web OAuth Client ID) is required on Android so that
  // authenticate() returns an idToken which Firebase Auth accepts.
  // On Web, the clientId is set via the meta tag in index.html.
  if (_supportsGoogleSignIn) {
    await GoogleSignIn.instance.initialize(
      serverClientId: kIsWeb
          ? null
          : '931195916704-j59hlrmtla5tdfk2ktis923u0b0d4h12.apps.googleusercontent.com',
    );
  }

  final container = ProviderContainer();
  // Notification setup is best-effort and must not block startup on platforms
  // where FCM/local notifications are unavailable.
  await container.read(notificationServiceProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EquisplitApp(),
    ),
  );
}
