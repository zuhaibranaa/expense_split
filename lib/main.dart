import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'src/app.dart';
import 'src/shared/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    MobileAds.instance.initialize();
  }

  // Initialize Google Sign In (Web uses meta tag for clientId)
  // We await it to ensure it's ready before usage (especially for renderButton on Web)
  await GoogleSignIn.instance.initialize();

  final container = ProviderContainer();
  // Don't await init completely if it blocks, but init() in NotificationService calls _initFirebaseMessaging
  // which might request permission. It is better to not block main() on permission request.
  // We'll update NotificationService to not await permission request or handle it gracefully.
  // But for now, ensuring Firebase is initialized is the critical fix.
  await container.read(notificationServiceProvider).init();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EquisplitApp(),
    ),
  );
}
