import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/responsive/responsive.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../features/auth/domain/validators.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/widgets/app_text_field.dart';
import '../../features/auth/presentation/widgets/google_button.dart';
import '../../features/auth/presentation/widgets/password_strength_meter.dart';
import '../../features/auth/presentation/widgets/primary_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _acceptedTerms = false;
  bool _showTermsError = false;
  String _pw = '';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _showTermsError = !_acceptedTerms);
    if (!formOk || !_acceptedTerms) return;
    FocusScope.of(context).unfocus();

    final user = await ref.read(authControllerProvider.notifier).register(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text.trim(),
        );
    if (user != null && mounted) {
      _snack('Account created — a verification email has been sent.');
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _googleSignUp() async {
    final user =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (user != null && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next is AsyncError) {
        _snack((next.error as AppException).message);
      }
    });
    final loading = ref.watch(authControllerProvider).isLoading;

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
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: FadeSlideIn(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const Center(child: AppLogo(height: 76)),
                        const SizedBox(height: 22),
                        const Text('Create your account',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Join SecureBank in a few seconds',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 14)),
                        const SizedBox(height: 26),
                        AppTextField(
                          controller: _name,
                          label: 'Full name',
                          icon: Icons.person_outline,
                          keyboardType: TextInputType.name,
                          validator: Validators.fullName,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _email,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _phone,
                          label: 'Phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+ ]')),
                          ],
                          validator: Validators.phone,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _password,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscure: true,
                          validator: Validators.password,
                          onChanged: (v) => setState(() => _pw = v),
                        ),
                        PasswordStrengthMeter(password: _pw),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _confirm,
                          label: 'Confirm password',
                          icon: Icons.lock_outline,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          validator: (v) =>
                              Validators.confirmPassword(v, _password.text),
                        ),
                        const SizedBox(height: 8),
                        _termsRow(),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: 'Create account',
                          loading: loading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 18),
                        _dividerOr(),
                        const SizedBox(height: 18),
                        GoogleButton(
                          label: 'Sign up with Google',
                          onPressed: loading ? null : _googleSignUp,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account?',
                                style: TextStyle(color: Colors.white60)),
                            TextButton(
                              onPressed: loading
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('Log in',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
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

  Widget _termsRow() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _acceptedTerms,
                  checkColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() {
                    _acceptedTerms = v ?? false;
                    if (_acceptedTerms) _showTermsError = false;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _acceptedTerms = !_acceptedTerms;
                    if (_acceptedTerms) _showTermsError = false;
                  }),
                  child: const Text.rich(
                    TextSpan(
                      text: 'I agree to the ',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                      children: [
                        TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                        TextSpan(text: ' and '),
                        TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showTermsError)
            const Padding(
              padding: EdgeInsets.only(left: 32, top: 2),
              child: Text('Please accept the terms to continue',
                  style: TextStyle(color: AppTokens.danger, fontSize: 12)),
            ),
        ],
      );

  Widget _dividerOr() => Row(
        children: const [
          Expanded(child: Divider(color: Colors.white24)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('or',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(child: Divider(color: Colors.white24)),
        ],
      );
}
