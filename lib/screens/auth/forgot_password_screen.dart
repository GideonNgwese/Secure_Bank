import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../features/auth/domain/validators.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/controllers/password_reset_controller.dart';
import '../../features/auth/presentation/widgets/app_text_field.dart';
import '../../features/auth/presentation/widgets/primary_button.dart';
import 'reset_otp_screen.dart';

/// Step 1 of password reset: enter your email. If the backend is configured we
/// send a 6-digit OTP via Brevo; otherwise we fall back to Firebase's reset
/// email so the feature still works before the backend is deployed.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();

    if (AppConfig.hasApi) {
      final ok =
          await ref.read(passwordResetControllerProvider.notifier).sendCode(email);
      if (ok && mounted) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ResetOtpScreen(email: email)));
      }
    } else {
      final ok =
          await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
      if (ok && mounted) {
        _snack('Reset link sent to $email. Check your inbox (and spam).');
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(passwordResetControllerProvider, (_, next) {
      if (next is AsyncError) _snack((next.error as AppException).message);
    });
    ref.listen(authControllerProvider, (_, next) {
      if (next is AsyncError) _snack((next.error as AppException).message);
    });
    final loading = ref.watch(passwordResetControllerProvider).isLoading ||
        ref.watch(authControllerProvider).isLoading;

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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Center(child: AppLogo(height: 72)),
                        const SizedBox(height: 26),
                        const Text('Forgot password?',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          AppConfig.hasApi
                              ? "Enter your email and we'll send you a "
                                  '6-digit verification code.'
                              : "Enter your email and we'll send you a "
                                  'password reset link.',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 28),
                        AppTextField(
                          controller: _email,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 20),
                        PrimaryButton(
                          label: AppConfig.hasApi
                              ? 'Send code'
                              : 'Send reset link',
                          loading: loading,
                          onPressed: _submit,
                        ),
                      ],
                    ),
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
