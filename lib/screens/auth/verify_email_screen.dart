import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/controllers/email_verification_controller.dart';
import '../../features/auth/presentation/widgets/otp_input.dart';
import '../../features/auth/presentation/widgets/primary_button.dart';

/// Shown by [AuthGate] for signed-in but unverified users.
///
/// - Backend configured → **Brevo OTP**: a 6-digit code is emailed; verifying
///   it tells the backend to mark the email verified (Admin SDK), then the gate
///   advances.
/// - No backend → **Firebase link** fallback: auto-polls until the emailed link
///   is opened.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final bool _otpMode = AppConfig.hasApi;

  Timer? _poll;
  Timer? _cooldownTimer;
  int _cooldown = 0;
  bool _busy = false;
  String _code = '';

  String get _email =>
      ref.read(authStateChangesProvider).valueOrNull?.email ?? '';

  @override
  void initState() {
    super.initState();
    if (_otpMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
    } else {
      // Poll for the emailed link being opened.
      _poll = Timer.periodic(const Duration(seconds: 5),
          (_) => ref.read(emailVerificationProvider.notifier).check());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  // ---- OTP (Brevo) mode ----
  Future<void> _sendCode() async {
    setState(() => _busy = true);
    try {
      await ref.read(otpApiServiceProvider).sendVerificationCode(_email);
      if (mounted) {
        _snack('Verification code sent to $_email');
        _startCooldown();
      }
    } catch (e) {
      if (mounted) _snack(mapError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_code.length < 6) {
      _snack('Enter the 6-digit code.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(otpApiServiceProvider).verifyEmailCode(_email, _code);
      final verified =
          await ref.read(emailVerificationProvider.notifier).check();
      if (!verified && mounted) {
        _snack('Verified — finishing up…');
      }
      // On success the gate (watching emailVerificationProvider) advances.
    } catch (e) {
      if (mounted) _snack(mapError(e).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- Firebase link mode ----
  Future<void> _checkNow() async {
    final verified = await ref.read(emailVerificationProvider.notifier).check();
    if (!verified && mounted) {
      _snack('Not verified yet. Open the link in your email, then try again.');
    }
  }

  Future<void> _resendLink() async {
    try {
      await ref.read(emailVerificationProvider.notifier).resend();
      if (mounted) {
        _snack('Verification email sent.');
        _startCooldown();
      }
    } catch (e) {
      if (mounted) _snack(mapError(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(),
      child: Builder(
        builder: (context) => Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppTokens.darkBgTop, AppTokens.darkBg],
              ),
            ),
            child: SafeArea(
              child: ResponsiveCenter(
                child: FadeSlideIn(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: AppLogo(height: 72)),
                      const SizedBox(height: 24),
                      const Icon(Icons.mark_email_unread_outlined,
                          color: Colors.white, size: 60),
                      const SizedBox(height: 20),
                      const Text('Verify your email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(
                        _otpMode
                            ? 'Enter the 6-digit code we sent to\n$_email'
                            : "We've sent a verification link to\n$_email.\n"
                                'Open it — this screen updates automatically.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      if (_otpMode)
                        ..._otpSection()
                      else
                        ..._linkSection(),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                        child: const Text('Use a different account',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _otpSection() => [
        OtpInput(
          enabled: !_busy,
          onChanged: (c) => _code = c,
          onCompleted: (c) {
            _code = c;
            _verifyCode();
          },
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Verify', loading: _busy, onPressed: _verifyCode),
        const SizedBox(height: 14),
        Center(
          child: _cooldown > 0
              ? Text('Resend code in ${_cooldown}s',
                  style: const TextStyle(color: Colors.white38))
              : TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: const Text('Resend code',
                      style: TextStyle(color: Colors.white)),
                ),
        ),
      ];

  List<Widget> _linkSection() => [
        PrimaryButton(label: "I've verified my email", onPressed: _checkNow),
        const SizedBox(height: 12),
        SecondaryButton(
          label: _cooldown > 0 ? 'Resend in ${_cooldown}s' : 'Resend email',
          icon: Icons.refresh,
          onPressed: _cooldown > 0 ? null : _resendLink,
        ),
      ];
}
