import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/services.dart' show PlatformException;

/// A user-facing, non-technical error. UI shows [message] directly; the
/// original error is never exposed to the user.
sealed class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => 'AppException($message)';
}

class AuthException extends AppException {
  const AuthException(super.message);
}

class NetworkException extends AppException {
  const NetworkException(
      [super.message =
          'No internet connection. Check your network and try again.']);
}

class ServerException extends AppException {
  const ServerException(
      [super.message = 'Something went wrong on our end. Please try again.']);
}

class CancelledException extends AppException {
  const CancelledException([super.message = 'Cancelled.']);
}

class UnknownAppException extends AppException {
  const UnknownAppException(
      [super.message = 'Something went wrong. Please try again.']);
}

/// Maps any thrown error into a friendly [AppException]. Central place so no
/// screen ever has to interpret a raw Firebase/Google/network error.
AppException mapError(Object error) {
  if (error is AppException) return error;
  if (error is FirebaseAuthException) {
    return AuthException(_firebaseAuthMessage(error.code));
  }
  // Other Firebase services (Firestore, etc.). Note: FirebaseAuthException is a
  // FirebaseException subtype, so it must be checked first (above).
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return const ServerException(
            'You don\'t have permission for that action.');
      case 'unavailable':
        return const NetworkException(
            'Service temporarily unavailable. Please try again.');
      default:
        return const ServerException();
    }
  }
  if (error is SocketException) return const NetworkException();
  if (error is TimeoutException) {
    return const NetworkException('The request timed out. Please try again.');
  }
  if (error is PlatformException) {
    return AuthException(_platformMessage(error.code));
  }
  if (error is HttpException) return const ServerException();
  return const UnknownAppException();
}

/// Google Sign-In / plugin channel errors surface as PlatformExceptions.
String _platformMessage(String code) {
  switch (code) {
    case 'network_error':
      return 'No internet connection. Check your network and try again.';
    case 'sign_in_canceled':
    case 'sign_in_cancelled':
      return 'Cancelled.';
    case 'sign_in_failed':
      return 'Google sign-in failed. Please try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

String _firebaseAuthMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'That email address looks invalid.';
    case 'user-disabled':
      return 'This account has been disabled. Contact support.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password.';
    case 'email-already-in-use':
      return 'An account already exists with this email.';
    case 'weak-password':
      return 'Please choose a stronger password.';
    case 'operation-not-allowed':
      return 'This sign-in method is not enabled.';
    case 'account-exists-with-different-credential':
      return 'This email is already linked to another sign-in method.';
    case 'network-request-failed':
      return 'No internet connection. Check your network and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'requires-recent-login':
      return 'Please log in again to continue.';
    case 'cancelled':
      return 'Cancelled.';
    default:
      return 'Authentication failed. Please try again.';
  }
}
