import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_providers.dart';
import '../../domain/auth_repository.dart';

/// Exposes whether the current user's email is verified, and lets the UI resend
/// the verification email or re-check status. The value is refreshable because
/// Firebase's `authStateChanges` does NOT re-emit when `emailVerified` flips.
class EmailVerificationController extends AutoDisposeAsyncNotifier<bool> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<bool> build() async {
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    return user?.emailVerified ?? false;
  }

  /// Reloads the auth user and returns the fresh verified flag.
  Future<bool> check() async {
    final verified = await _repo.refreshEmailVerified();
    state = AsyncData(verified);
    return verified;
  }

  Future<void> resend() => _repo.sendEmailVerification();
}

final emailVerificationProvider =
    AutoDisposeAsyncNotifierProvider<EmailVerificationController, bool>(
        EmailVerificationController.new);
