import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/firebase/firebase_error_mapper.dart';
import '../../../core/firebase/firestore_refs.dart';
import '../../../shared/services/notification_service.dart';
import '../domain/user_model.dart';

/// Firebase Auth + Firestore-backed user profile.
///
/// Session state is derived from `authStateChanges()`; nothing is persisted in
/// SharedPreferences anymore.
class AuthRepository {
  AuthRepository(
    this._auth,
    this._refs,
    this._storage,
    this._notificationService,
  );

  final fb.FirebaseAuth _auth;
  final FirestoreRefs _refs;
  final FirebaseStorage _storage;
  final NotificationService _notificationService;

  User? _currentUser;

  User? get currentUser => _currentUser;

  /// Emits the signed-in [User] whenever either the Auth user or the Firestore
  /// profile changes; emits `null` on sign-out.
  Stream<User?> watchCurrentUser() {
    return _auth.authStateChanges().asyncExpand((firebaseUser) {
      if (firebaseUser == null) {
        _currentUser = null;
        return Stream<User?>.value(null);
      }

      return Stream.fromFuture(_ensureUserDocument(firebaseUser)).asyncExpand((
        _,
      ) {
        return _refs.user(firebaseUser.uid).snapshots().map((snapshot) {
          final user = _fromAuthAndDoc(firebaseUser, snapshot);
          _currentUser = user;
          _syncDeviceToken();
          return user;
        });
      });
    });
  }

  Future<void> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser != null) {
        await _ensureUserDocument(firebaseUser);
      }
    } on fb.FirebaseAuthException catch (error) {
      throw Exception(mapFirebaseError(error));
    }
  }

  Future<void> register(
    String email,
    String password,
    String confirmPassword,
    String name,
    String currency,
  ) async {
    if (password != confirmPassword) {
      throw Exception('Passwords do not match.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Account creation failed. Please try again.');
      }

      await firebaseUser.updateDisplayName(name);
      await _refs.user(firebaseUser.uid).set({
        'uid': firebaseUser.uid,
        'name': name,
        'email': email,
        'avatarUrl': null,
        'defaultCurrency': currency,
        'phone': null,
        'iban': null,
        'isPremium': false,
        'premiumUntil': null,
        'personalGroupId': null,
        'hasPassword': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Best effort: verification email and device token should not block
      // account creation if the network hiccups.
      try {
        await firebaseUser.sendEmailVerification();
      } catch (error) {
        debugPrint('Could not send verification email: $error');
      }
      unawaited(_syncDeviceToken());
    } on fb.FirebaseAuthException catch (error) {
      throw Exception(mapFirebaseError(error));
    }
  }

  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      // Web sign-in is driven by Google Identity Services' renderButton and
      // the `authenticationEvents` listener in [AuthController].
      return;
    }

    try {
      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email'],
      );
      await handleGoogleAuth(googleUser);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return;
      throw Exception(error.description ?? 'Google Sign-In failed.');
    }
  }

  Future<void> handleGoogleAuth(GoogleSignInAccount googleUser) async {
    try {
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('Could not get a Google ID token.');
      }

      // google_sign_in 7.x exposes the access token through the authorization
      // client instead of the authentication object.
      String? accessToken;
      try {
        final authorization = await googleUser.authorizationClient
            .authorizationForScopes(const ['email']);
        accessToken = authorization?.accessToken;
      } catch (error) {
        debugPrint('Could not get a Google access token: $error');
      }

      final credential = fb.GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await _ensureUserDocument(firebaseUser);
      }
    } on fb.FirebaseAuthException catch (error) {
      throw Exception(mapFirebaseError(error));
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return;
      throw Exception(error.description ?? 'Google Sign-In failed.');
    }
  }

  /// Creates the profile document on first sign-in (Google) or repairs a
  /// missing document. The `bootstrapUser` Cloud Function reacts to creation
  /// and seeds the personal group + default categories.
  Future<void> _ensureUserDocument(fb.User firebaseUser) async {
    final ref = _refs.user(firebaseUser.uid);
    final snapshot = await ref.get();
    if (snapshot.exists) {
      unawaited(_syncDeviceToken());
      return;
    }

    final displayName = (firebaseUser.displayName ?? '').trim();
    final email = firebaseUser.email ?? '';
    await ref.set({
      'uid': firebaseUser.uid,
      'name': displayName.isNotEmpty ? displayName : email.split('@').first,
      'email': email,
      'avatarUrl': firebaseUser.photoURL,
      'defaultCurrency': 'USD',
      'phone': firebaseUser.phoneNumber,
      'iban': null,
      'isPremium': false,
      'premiumUntil': null,
      'personalGroupId': null,
      'hasPassword': _hasPasswordProvider(firebaseUser),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  User _fromAuthAndDoc(
    fb.User firebaseUser,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final user = User.fromMap(firebaseUser.uid, snapshot.data() ?? const {});
    return user.copyWith(
      email: firebaseUser.email ?? user.email,
      isVerified: firebaseUser.emailVerified,
      hasPassword: _hasPasswordProvider(firebaseUser),
      avatarUrl: user.avatarUrl ?? firebaseUser.photoURL,
      name: user.name.isEmpty
          ? (firebaseUser.displayName ?? 'User')
          : user.name,
    );
  }

  bool _hasPasswordProvider(fb.User firebaseUser) {
    return firebaseUser.providerData.any(
      (provider) => provider.providerId == 'password',
    );
  }

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
    String? currency,
    String? phone,
    String? iban,
    String? password,
    String? passwordConfirmation,
    String? currentPassword,
    bool shouldHandleError = true,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    try {
      final updates = <String, dynamic>{
        'name': ?name?.trim(),
        'avatarUrl': ?avatarUrl,
        'defaultCurrency': ?currency,
        if (phone != null) 'phone': phone.trim().isEmpty ? null : phone.trim(),
        if (iban != null) 'iban': iban.trim().isEmpty ? null : iban.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (updates.length > 1) {
        await _refs
            .user(firebaseUser.uid)
            .set(updates, SetOptions(merge: true));
      }

      if (name != null && name.trim().isNotEmpty) {
        await firebaseUser.updateDisplayName(name.trim());
      }

      if (password != null && password.isNotEmpty) {
        if (password != passwordConfirmation) {
          throw Exception('Passwords do not match.');
        }
        await _updatePassword(firebaseUser, password, currentPassword);
      }
    } on fb.FirebaseAuthException catch (error) {
      if (!shouldHandleError) rethrow;
      throw Exception(mapFirebaseError(error));
    }
  }

  Future<void> _updatePassword(
    fb.User firebaseUser,
    String newPassword,
    String? currentPassword,
  ) async {
    final email = firebaseUser.email;
    if (email == null) {
      throw Exception('This account has no email address.');
    }

    if (_hasPasswordProvider(firebaseUser)) {
      if (currentPassword == null || currentPassword.isEmpty) {
        throw Exception('Enter your current password.');
      }
      final credential = fb.EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await firebaseUser.reauthenticateWithCredential(credential);
      await firebaseUser.updatePassword(newPassword);
    } else {
      final credential = fb.EmailAuthProvider.credential(
        email: email,
        password: newPassword,
      );
      await firebaseUser.linkWithCredential(credential);
      await _refs.user(firebaseUser.uid).set({
        'hasPassword': true,
      }, SetOptions(merge: true));
    }
  }

  Future<User?> refreshUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    await firebaseUser.reload();
    final refreshed = _auth.currentUser ?? firebaseUser;
    final snapshot = await _refs.user(refreshed.uid).get();
    final user = _fromAuthAndDoc(refreshed, snapshot);
    _currentUser = user;
    return user;
  }

  Future<String> uploadAvatar(XFile file) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw Exception('You must be signed in to upload an avatar.');
    }

    final bytes = await file.readAsBytes();
    final extension = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };

    final ref = _storage.ref('avatars/${firebaseUser.uid}/profile.$extension');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    await _refs.user(firebaseUser.uid).set({
      'avatarUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return url;
  }

  Future<void> requestVerification() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || firebaseUser.emailVerified) return;

    try {
      await firebaseUser.sendEmailVerification();
    } on fb.FirebaseAuthException catch (error) {
      throw Exception(mapFirebaseError(error));
    }
  }

  Future<void> logout() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      await _removeDeviceToken(firebaseUser.uid);
    }
    await _auth.signOut();
    _currentUser = null;
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (error) {
      throw Exception(mapFirebaseError(error));
    }
  }

  Future<void> _syncDeviceToken() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    try {
      final token = await _notificationService.getFcmToken();
      if (token == null || token.isEmpty) return;

      final deviceId = token.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      await _refs.devices(firebaseUser.uid).doc(deviceId).set({
        'token': token,
        'platform': _platformName,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

    } catch (error) {
      debugPrint('Could not sync FCM token: $error');
    }
  }

  Future<void> _removeDeviceToken(String uid) async {
    try {
      final token = await _notificationService.getFcmToken();
      if (token == null || token.isEmpty) return;
      final deviceId = token.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      await _refs.devices(uid).doc(deviceId).delete();
    } catch (error) {
      debugPrint('Could not remove FCM token: $error');
    }
  }



  String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      _ => 'unknown',
    };
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreRefsProvider),
    ref.watch(firebaseStorageProvider),
    ref.watch(notificationServiceProvider),
  );
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<User?>>((ref) {
      return AuthController(ref);
    });

class AuthController extends StateNotifier<AsyncValue<User?>> {
  AuthController(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final Ref ref;
  StreamSubscription<User?>? _userSubscription;

  void _init() {
    final repo = ref.read(authRepositoryProvider);

    if (kIsWeb) {
      GoogleSignIn.instance.authenticationEvents.listen((event) async {
        final dynamic dynamicEvent = event;
        try {
          final user = dynamicEvent.user;
          if (user is GoogleSignInAccount) {
            await repo.handleGoogleAuth(user);
          }
        } catch (_) {
          // Events other than sign-in do not carry a `user`.
        }
      });
    }

    _userSubscription = repo.watchCurrentUser().listen(
      (user) {
        state = AsyncValue.data(user);
      },
      onError: (Object error, StackTrace stack) {
        state = AsyncValue.error(error, stack);
      },
    );

    ref.onDispose(() => _userSubscription?.cancel());
  }

  Future<void> login(String email, String password) async {
    await ref.read(authRepositoryProvider).login(email, password);
  }

  Future<void> register(
    String email,
    String password,
    String confirmPassword,
    String name,
    String currency,
  ) async {
    await ref
        .read(authRepositoryProvider)
        .register(email, password, confirmPassword, name, currency);
  }

  Future<void> signInWithGoogle() async {
    await ref.read(authRepositoryProvider).signInWithGoogle();
  }

  Future<void> updateProfile({
    String? name,
    String? avatarUrl,
    String? currency,
    String? phone,
    String? iban,
    String? password,
    String? passwordConfirmation,
    String? currentPassword,
    bool shouldHandleError = true,
  }) async {
    try {
      await ref
          .read(authRepositoryProvider)
          .updateProfile(
            name: name,
            avatarUrl: avatarUrl,
            currency: currency,
            phone: phone,
            iban: iban,
            password: password,
            passwordConfirmation: passwordConfirmation,
            currentPassword: currentPassword,
            shouldHandleError: shouldHandleError,
          );
      state = AsyncValue.data(ref.read(authRepositoryProvider).currentUser);
    } catch (error) {
      // Keep the previous data state so AuthGate does not sign the user out.
      rethrow;
    }
  }

  Future<void> reloadUser() async {
    try {
      final user = await ref.read(authRepositoryProvider).refreshUser();
      if (user != null) state = AsyncValue.data(user);
    } catch (error) {
      debugPrint('Failed to reload user: $error');
    }
  }

  Future<void> requestVerification() async {
    await ref.read(authRepositoryProvider).requestVerification();
  }

  Future<void> uploadAvatar(XFile file) async {
    try {
      await ref.read(authRepositoryProvider).uploadAvatar(file);
      state = AsyncValue.data(ref.read(authRepositoryProvider).currentUser);
    } on Exception {
      rethrow;
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(null);
  }

  Future<void> forgotPassword(String email) async {
    await ref.read(authRepositoryProvider).forgotPassword(email);
  }
}
