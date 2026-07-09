import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/auth_providers.dart';
import '../../data/services/otp_api_service.dart';

/// Drives the OTP password-reset flow. Each method returns `true` on success;
/// on failure it sets `AsyncError(AppException)` so the UI shows the message.
class PasswordResetController extends AutoDisposeAsyncNotifier<void> {
  OtpApiService get _api => ref.read(otpApiServiceProvider);

  @override
  FutureOr<void> build() {}

  Future<bool> _guard(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
      return false;
    }
  }

  Future<bool> sendCode(String email) => _guard(() => _api.sendResetCode(email));

  Future<bool> verifyCode(String email, String code) =>
      _guard(() => _api.verifyResetCode(email, code));

  Future<bool> resetPassword(String email, String code, String newPassword) =>
      _guard(() => _api.resetPassword(email, code, newPassword));
}

final passwordResetControllerProvider =
    AutoDisposeAsyncNotifierProvider<PasswordResetController, void>(
        PasswordResetController.new);
