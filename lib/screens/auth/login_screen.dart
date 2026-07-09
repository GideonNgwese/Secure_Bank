import 'package:flutter/material.dart';
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
import '../../features/auth/presentation/widgets/primary_button.dart';
import '../../services/secure_login.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _secure = SecureLogin();

  bool _rememberMe = false;
  bool _biometricReady = false;

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadRemembered() async {
    if (!await _secure.isRemembered()) return;
    final email = await _secure.savedEmail();
    final canBio = await _secure.canUseBiometrics();
    if (mounted) {
      setState(() {
        _rememberMe = true;
        if (email != null) _email.text = email;
        _biometricReady = canBio;
      });
    }
  }

  void _goHome() => Navigator.of(context).popUntil((r) => r.isFirst);

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final user = await ref
        .read(authControllerProvider.notifier)
        .signIn(_email.text.trim(), _password.text.trim());
    if (user == null || !mounted) return;
    if (_rememberMe) {
      await _secure.saveCredentials(_email.text.trim(), _password.text.trim());
    } else {
      await _secure.clear();
    }
    if (mounted) _goHome();
  }

  Future<void> _biometricLogin() async {
    final email = await _secure.savedEmail();
    final password = await _secure.savedPassword();
    if (email == null || password == null) {
      _snack('No saved login yet. Log in once with "Remember me" checked first.');
      return;
    }
    if (!await _secure.authenticate()) {
      _snack('Fingerprint not recognized. Use your password, or enrol a '
          'fingerprint on the phone.');
      return;
    }
    final user =
        await ref.read(authControllerProvider.notifier).signIn(email, password);
    if (user != null && mounted) _goHome();
  }

  Future<void> _googleLogin() async {
    final user =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (user != null && mounted) _goHome();
  }

  void _forgotPassword() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));

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
                        const Center(child: AppLogo(height: 92)),
                        const SizedBox(height: 26),
                        const Text('Good to see you again',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text(
                            'Sign in to pick up where you left off',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 14)),
                        const SizedBox(height: 28),
                        AppTextField(
                          controller: _email,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                          controller: _password,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscure: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Password is required'
                              : null,
                        ),
                        _rememberRow(),
                        const SizedBox(height: 8),
                        PrimaryButton(
                          label: 'Log in',
                          loading: loading,
                          onPressed: _submit,
                        ),
                        if (_biometricReady) ...[
                          const SizedBox(height: 12),
                          SecondaryButton(
                            label: 'Log in with fingerprint',
                            icon: Icons.fingerprint,
                            onPressed: loading ? null : _biometricLogin,
                          ),
                        ],
                        const SizedBox(height: 22),
                        _dividerOr(),
                        const SizedBox(height: 22),
                        GoogleButton(onPressed: loading ? null : _googleLogin),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account?",
                                style: TextStyle(color: Colors.white60)),
                            TextButton(
                              onPressed: loading
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen())),
                              child: const Text('Register',
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

  Widget _rememberRow() => Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _rememberMe,
              checkColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => setState(() => _rememberMe = v ?? false),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            child: const Text('Remember me',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          const Spacer(),
          TextButton(
            onPressed: _forgotPassword,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: Colors.white,
            ),
            child:
                const Text('Forgot password?', style: TextStyle(fontSize: 13)),
          ),
        ],
      );

  Widget _dividerOr() => Row(
        children: const [
          Expanded(child: Divider(color: Colors.white24)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('or continue with',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(child: Divider(color: Colors.white24)),
        ],
      );
}
