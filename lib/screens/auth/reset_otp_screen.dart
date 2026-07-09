import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../features/auth/presentation/controllers/password_reset_controller.dart';
import '../../features/auth/presentation/widgets/otp_input.dart';
import '../../features/auth/presentation/widgets/primary_button.dart';
import 'new_password_screen.dart';

/// Step 2: enter the 6-digit OTP that Brevo emailed. Verifies with the backend,
/// then continues to set a new password.
class ResetOtpScreen extends ConsumerStatefulWidget {
  final String email;
  const ResetOtpScreen({super.key, required this.email});

  @override
  ConsumerState<ResetOtpScreen> createState() => _ResetOtpScreenState();
}

class _ResetOtpScreenState extends ConsumerState<ResetOtpScreen> {
  String _code = '';
  int _cooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _verify() async {
    if (_code.length < 6) {
      _snack('Enter the 6-digit code.');
      return;
    }
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .verifyCode(widget.email, _code);
    if (ok && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              NewPasswordScreen(email: widget.email, code: _code)));
    }
  }

  Future<void> _resend() async {
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .sendCode(widget.email);
    if (ok && mounted) {
      _snack('A new code has been sent.');
      _startCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(passwordResetControllerProvider, (_, next) {
      if (next is AsyncError) _snack((next.error as AppException).message);
    });
    final loading = ref.watch(passwordResetControllerProvider).isLoading;

    return Theme(
      data: AppTheme.dark(),
      child: Builder(
        builder: (context) => Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      const Center(child: AppLogo(height: 72)),
                      const SizedBox(height: 26),
                      const Text('Enter the code',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'We sent a 6-digit code to\n${widget.email}',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      OtpInput(
                        enabled: !loading,
                        onChanged: (c) => _code = c,
                        onCompleted: (c) {
                          _code = c;
                          _verify();
                        },
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                          label: 'Verify', loading: loading, onPressed: _verify),
                      const SizedBox(height: 16),
                      Center(
                        child: _cooldown > 0
                            ? Text('Resend code in ${_cooldown}s',
                                style: const TextStyle(color: Colors.white38))
                            : TextButton(
                                onPressed: loading ? null : _resend,
                                child: const Text('Resend code',
                                    style: TextStyle(color: Colors.white)),
                              ),
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
}
