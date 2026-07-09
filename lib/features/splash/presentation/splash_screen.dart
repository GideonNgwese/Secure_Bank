import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/auth_gate.dart';
import '../../../core/navigation/navigation_service.dart';
import '../../../core/services/app_startup_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../onboarding/onboarding_providers.dart';
import '../../onboarding/presentation/onboarding_screen.dart';

/// Cinematic branded splash: dark navy background with soft blue glows, a logo
/// reveal (fade → scale → glow), tagline, and a slim progress line. While it
/// plays it resolves the next destination (onboarding vs app) and navigates.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..repeat(reverse: true);

  late final Animation<double> _bg = _curve(0.0, 0.18);
  late final Animation<double> _logoOpacity = _curve(0.12, 0.34);
  late final Animation<double> _logoScale =
      Tween(begin: 0.85, end: 1.0).animate(_curve(0.22, 0.52));
  late final Animation<double> _glow = _curve(0.42, 0.72);
  late final Animation<double> _tagline = _curve(0.62, 0.9);

  CurvedAnimation _curve(double begin, double end) => CurvedAnimation(
      parent: _reveal, curve: Interval(begin, end, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _startup();
  }

  @override
  void dispose() {
    _reveal.dispose();
    _ambient.dispose();
    super.dispose();
  }

  Future<void> _startup() async {
    // Resolve destination (logs the decision) while the reveal animation plays.
    final routeFuture = ref.read(startupRouteProvider.future);
    await _reveal.forward();
    final route = await routeFuture;
    if (!mounted) return;
    final next = route == StartupRoute.onboarding
        ? const OnboardingScreen()
        : const AuthGate();
    NavigationService.replaceWith(context, next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A16),
      body: AnimatedBuilder(
        animation: Listenable.merge([_reveal, _ambient]),
        builder: (context, _) {
          return Opacity(
            opacity: _bg.value,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _background(),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _logo(),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: _tagline.value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - _tagline.value) * 12),
                          child: const Text(
                            'Smart Finance. Secure Future.',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 56,
                  child: Center(child: _progressLine()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _background() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1428), Color(0xFF060A16)],
        ),
      ),
      child: Stack(
        children: [
          _glowOrb(const Alignment(-0.8, -0.7), 260, 0.18),
          _glowOrb(const Alignment(0.9, 0.6), 300, 0.14),
          _glowOrb(const Alignment(0.2, -1.0), 200, 0.10),
        ],
      ),
    );
  }

  Widget _glowOrb(Alignment align, double size, double opacity) {
    final pulse = 0.9 + 0.1 * math.sin(_ambient.value * math.pi);
    return Align(
      alignment: align,
      child: Container(
        width: size * pulse,
        height: size * pulse,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            AppTokens.brand.withValues(alpha: opacity * _bg.value),
            Colors.transparent,
          ]),
        ),
      ),
    );
  }

  Widget _logo() {
    return Opacity(
      opacity: _logoOpacity.value,
      child: Transform.scale(
        scale: _logoScale.value,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // soft blue glow behind the logo
            Container(
              width: 220,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppTokens.brand
                        .withValues(alpha: 0.45 * _glow.value),
                    blurRadius: 60 * _glow.value,
                    spreadRadius: 8 * _glow.value,
                  ),
                ],
              ),
            ),
            const AppLogo(height: 130),
          ],
        ),
      ),
    );
  }

  Widget _progressLine() {
    return SizedBox(
      width: 140,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: _reveal.value,
          minHeight: 3,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          valueColor: const AlwaysStoppedAnimation(AppTokens.brand),
        ),
      ),
    );
  }
}
