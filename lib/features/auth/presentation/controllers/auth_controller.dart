import 'dart:async';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../email/data/email_providers.dart';
import '../../data/auth_providers.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_user.dart';

/// Drives the auth screens. Its [state] is an `AsyncValue<void>`:
/// - `AsyncLoading` while a request is in flight (buttons show spinners)
/// - `AsyncError(AppException)` on failure (UI shows the friendly message)
/// - `AsyncData` when idle/succeeded.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  FutureOr<void> build() {}

  Future<AuthUser?> _run(Future<AuthUser> Function() action) async {
    state = const AsyncLoading();
    try {
      final user = await action();
      state = const AsyncData(null);
      return user;
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
      return null;
    }
  }

  Future<AuthUser?> signIn(String email, String password) =>
      _run(() => _repo.signInWithEmail(email: email, password: password));

  Future<AuthUser?> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final user = await _run(() => _repo.registerWithEmail(
          fullName: fullName,
          email: email,
          phone: phone,
          password: password,
        ));
    if (user != null) {
      unawaited(ref.read(emailRepositoryProvider).accountCreated(
          userId: user.uid, email: user.email, name: user.fullName));
    }
    return user;
  }

  Future<AuthUser?> signInWithGoogle() async {
    final user = await _run(() => _repo.signInWithGoogle());
    if (user != null) {
      unawaited(ref.read(emailRepositoryProvider).googleSignIn(
          userId: user.uid,
          email: user.email,
          name: user.fullName,
          deviceInfo: defaultTargetPlatform.name));
    }
    return user;
  }

  /// Returns true if the reset email was sent; sets AsyncError otherwise.
  Future<bool> sendPasswordReset(String email) async {
    state = const AsyncLoading();
    try {
      await _repo.sendPasswordResetEmail(email);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    try {
      await _repo.signOut();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
    }
  }
}

final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>(AuthController.new);
