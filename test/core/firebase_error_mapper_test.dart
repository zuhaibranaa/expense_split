import 'package:cloud_functions/cloud_functions.dart';
import 'package:equisplit/src/core/firebase/firebase_error_mapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a missing account to a create-account hint', () {
    expect(
      mapFirebaseError(FirebaseAuthException(code: 'user-not-found')),
      'No account found for that email. Create one first.',
    );
  });

  test('maps invalid credentials to a single message', () {
    for (final code in ['wrong-password', 'invalid-credential']) {
      expect(
        mapFirebaseError(FirebaseAuthException(code: code)),
        'Incorrect email or password.',
      );
    }
  });

  test('maps weak passwords and duplicate accounts', () {
    expect(
      mapFirebaseError(FirebaseAuthException(code: 'weak-password')),
      'Password must be at least 6 characters.',
    );
    expect(
      mapFirebaseError(FirebaseAuthException(code: 'email-already-in-use')),
      'An account already exists for that email.',
    );
  });

  test('passes through callable messages', () {
    expect(
      mapFirebaseError(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'They have not enabled notifications yet.',
        ),
      ),
      'They have not enabled notifications yet.',
    );
    expect(
      mapFirebaseError(
        FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'You already sent a reminder today.',
        ),
      ),
      'You already sent a reminder today.',
    );
  });

  test('falls back to a generic message for unknown auth errors', () {
    expect(
      mapFirebaseError(FirebaseAuthException(code: 'unknown-error')),
      'Authentication failed. Please try again.',
    );
  });
}
