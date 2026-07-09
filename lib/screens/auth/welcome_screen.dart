import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/widgets/app_logo.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Minimal premium auth landing (distinct from the first-run onboarding):
/// brand logo on a dark gradient with soft glows, a short tagline, and the two
/// primary actions — Create account / Log in.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat(reverse: true);

  static const _accentA = Color(0xFF3E74FF);
  static const _accentB = Color(0xFF9B37E0);

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A16),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A1428), Color(0xFF060A16)],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _ambient,
            builder: (_, __) {
              final p = 0.85 + 0.15 * math.sin(_ambient.value * math.pi);
              return Stack(
                children: [
                  _glow(const Alignment(-0.9, -0.6), 280 * p, _accentA, 0.16),
                  _glow(const Alignment(1.0, 0.5), 320 * p, _accentB, 0.14),
                ],
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  const AppLogo(height: 120),
                  const SizedBox(height: 26),
                  const Text(
                    'Smart finance.\nSecure future.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      height: 1.25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your bank and mobile money — protected, '
                    'organized, and always in one place.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white60, fontSize: 14, height: 1.5),
                  ),
                  const Spacer(flex: 4),
                  _primaryButton(
                    'Create account',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const RegisterScreen())),
                  ),
                  const SizedBox(height: 14),
                  _secondaryButton(
                    'Log in',
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const LoginScreen())),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Alignment a, double size, Color color, double opacity) {
    return Align(
      alignment: a,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [color.withValues(alpha: opacity), Colors.transparent]),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_accentA, _accentB]),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
                color: _accentB.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8)),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.10),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
