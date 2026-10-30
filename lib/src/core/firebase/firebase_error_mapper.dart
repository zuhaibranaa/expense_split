import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Converts Firebase exceptions into short, user-facing messages.
/// Never surface raw exception text in the UI.
String mapFirebaseError(Object error) {
  if (error is FirebaseAuthMultiFactorException) {
    return 'Multi-factor authentication is required.';
  }

  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
        return 'No account found for that email. Create one first.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      case 'requires-recent-login':
        return 'Please sign in again before changing your credentials.';
      case 'provider-already-linked':
        return 'This sign-in method is already linked to your account.';
      case 'credential-already-in-use':
        return 'That credential is already used by another account.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Please sign in again.';
      case 'permission-denied':
        return error.message ?? 'You do not have permission to do that.';
      case 'not-found':
        return error.message ?? 'That item no longer exists.';
      case 'already-exists':
        return error.message ?? 'That item already exists.';
      case 'failed-precondition':
        return error.message ?? 'This action cannot be completed right now.';
      case 'invalid-argument':
        return error.message ?? 'Invalid request.';
      case 'resource-exhausted':
        return error.message ?? 'Too many requests. Try again later.';
      default:
        return error.message ?? 'Request failed. Please try again.';
    }
  }

  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'unavailable':
        return 'You appear to be offline. Changes will sync when you reconnect.';
      case 'not-found':
        return 'That item no longer exists.';
      case 'deadline-exceeded':
        return 'The request timed out. Please try again.';
      case 'cancelled':
        return 'The request was cancelled.';
      case 'unauthorized':
        return 'You are not allowed to upload that file.';
      case 'object-not-found':
        return 'That file no longer exists.';
      case 'quota-exceeded':
        return 'Storage quota exceeded. Try a smaller file.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }

  return error.toString();
}
