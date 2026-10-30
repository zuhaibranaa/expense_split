import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';

const bool useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
);
const bool enableAppCheck = bool.fromEnvironment('ENABLE_APP_CHECK');

/// Host used by emulator-aware plugins. The Android emulator cannot resolve
/// `localhost` to the developer machine, so it uses 10.0.2.2 instead.
String get _emulatorHost {
  if (kIsWeb) return 'localhost';
  return defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';
}

/// Initializes Firebase and, when requested, points every plugin at the local
/// emulator suite. Call once from `main()` before anything reads Firebase.
Future<void> initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (useFirebaseEmulators) {
    final host = _emulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseStorage.instance.useStorageEmulator(host, 9199);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  }

  await _activateAppCheck();
}

Future<void> _activateAppCheck() async {
  if (!enableAppCheck) return;

  try {
    // App Check is optional during development and until parity QA passes.
    // Enforcement is configured in the Firebase console, never in the client.
    if (kIsWeb) {
      const siteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');
      if (siteKey.isEmpty) return;
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(siteKey),
      );
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await FirebaseAppCheck.instance.activate(
        providerApple: const AppleAppAttestProvider(),
      );
    }
  } catch (error, stack) {
    debugPrint('App Check activation skipped: $error');
    debugPrintStack(stackTrace: stack);
  }
}
