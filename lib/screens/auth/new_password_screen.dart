import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../features/auth/domain/validators.dart';
import '../../features/auth/presentation/controllers/password_reset_controller.dart';
import '../../features/auth/presentation/widgets/app_text_field.dart';
import '../../features/auth/presentation/widgets/password_strength_meter.dart';
import '../../features/auth/presentation/widgets/primary_button.dart';

/// Step 3: choose a new password. On success the backend updates Firebase Auth
/// (Admin SDK); the user returns to the login/welcome flow.
class NewPasswordScreen extends ConsumerStatefulWidget {
  final String email;
  final String code;
  const NewPasswordScreen({super.key, required this.email, required this.code});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _pw = '';

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await ref
        .read(passwordResetControllerProvider.notifier)
        .resetPassword(widget.email, widget.code, _password.text.trim());
    if (ok && mounted) {
      await _showSuccess();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _showSuccess() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        });
        return Dialog(
          backgroundColor: AppTokens.darkSurface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (_, t, __) => Transform.scale(
                    scale: t,
                    child: const CircleAvatar(
                      radius: 34,
                      backgroundColor: AppTokens.success,
                      child: Icon(Icons.check, color: Colors.white, size: 38),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Password updated',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('You can now log in with your new password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Center(child: AppLogo(height: 72)),
                        const SizedBox(height: 26),
                        const Text('Set a new password',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Choose a strong password you haven\'t '
                            'used before.',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 14)),
                        const SizedBox(height: 26),
                        AppTextField(
                          controller: _password,
                          label: 'New password',
                          icon: Icons.lock_outline,
                          obscure: true,
                          validator: Validators.password,
                          onChanged: (v) => setState(() => _pw = v),
                        ),
                        PasswordStrengthMeter(password: _pw),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _confirm,
                          label: 'Confirm new password',
                          icon: Icons.lock_outline,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          validator: (v) =>
                              Validators.confirmPassword(v, _password.text),
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(
                            label: 'Update password',
                            loading: loading,
                            onPressed: _submit),
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
