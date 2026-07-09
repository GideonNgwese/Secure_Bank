import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/auth_gate.dart';
import '../../../core/navigation/navigation_service.dart';
import 'controllers/onboarding_controller.dart';

/// Premium 3-slide onboarding shown once on first launch. Educates the user,
/// persists completion via [OnboardingController] → [OnboardingRepository],
/// then routes into the app's [AuthGate].
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  late final AnimationController _ambient = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat(reverse: true);
  int _index = 0;

  static const _accentA = Color(0xFF3E74FF);
  static const _accentB = Color(0xFF9B37E0);

  @override
  void dispose() {
    _pageController.dispose();
    _ambient.dispose();
    super.dispose();
  }

  bool get _isLast => _index == 2;

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider.notifier).complete();
    if (!mounted) return;
    NavigationService.replaceWith(context, const AuthGate());
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A16),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1428), Color(0xFF060A16)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: _isLast ? 0 : 1,
                  duration: const Duration(milliseconds: 250),
                  child: TextButton(
                    onPressed: _isLast ? null : _finish,
                    child: const Text('Skip',
                        style: TextStyle(color: Colors.white60)),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _slide(
                      art: _artAccounts(),
                      title: 'All Your Finances In One Place',
                      description:
                          'Manage your bank and mobile money accounts from '
                          'one secure dashboard.',
                    ),
                    _slide(
                      art: _artTransactions(),
                      title: 'Track Every Transaction',
                      description:
                          'Monitor income, expenses, spending habits, and '
                          'financial activities effortlessly.',
                    ),
                    _slide(
                      art: _artFraud(),
                      title: 'Stay Protected From Fraud',
                      description:
                          'Detect suspicious activities and receive smart '
                          'financial alerts.',
                    ),
                  ],
                ),
              ),
              _dots(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: _primaryButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slide({
    required Widget art,
    required String title,
    required String description,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: Center(child: art)),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.2),
              ),
              const SizedBox(height: 14),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [_accentA, _accentB])
                : null,
            color: active ? null : Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _primaryButton() {
    return SizedBox(
      height: 56,
      width: double.infinity,
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
          onPressed: _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: Text(_isLast ? 'Get Started' : 'Next',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // ---------------- Illustrations (built with widgets + micro-animation) ----

  Widget _artAccounts() {
    return AnimatedBuilder(
      animation: _ambient,
      builder: (_, __) {
        final f = math.sin(_ambient.value * math.pi * 2);
        return SizedBox(
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: Offset(-46, 24 + f * 6),
                child: Transform.rotate(
                    angle: -0.14,
                    child: _miniCard(
                        [const Color(0xFF2E5BFF), _accentB], 'MTN MoMo', '••4582')),
              ),
              Transform.translate(
                offset: Offset(46, -12 - f * 6),
                child: Transform.rotate(
                    angle: 0.12,
                    child: _miniCard(
                        [_accentB, const Color(0xFFE0218A)], 'UBA Bank', '••1290')),
              ),
              Transform.translate(
                offset: Offset(0, f * 4),
                child: _balanceChip(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniCard(List<Color> colors, String name, String number) {
    return Container(
      width: 168,
      height: 104,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: colors.last.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              const Icon(Icons.contactless, color: Colors.white70, size: 16),
            ],
          ),
          const Spacer(),
          Container(width: 26, height: 18, decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 6),
          Text(number,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, letterSpacing: 1.5)),
        ],
      ),
    );
  }

  Widget _balanceChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.25), blurRadius: 16)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('Total balance',
              style: TextStyle(color: Color(0xFF7A8699), fontSize: 10)),
          Text('215,000 FCFA',
              style: TextStyle(
                  color: Color(0xFF0A1428),
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _artTransactions() {
    return AnimatedBuilder(
      animation: _ambient,
      builder: (_, __) {
        final base = [0.5, 0.82, 0.42, 0.98, 0.66];
        return SizedBox(
          height: 240,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 110,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(base.length, (i) {
                    final wobble =
                        0.9 + 0.1 * math.sin(_ambient.value * math.pi * 2 + i);
                    return Container(
                      width: 18,
                      height: 110 * base[i] * wobble,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [_accentA, _accentB],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              _txRow(Icons.arrow_downward, 'Salary', '+150,000',
                  const Color(0xFF1FA96A)),
              const SizedBox(height: 8),
              _txRow(Icons.arrow_upward, 'Groceries', '-12,500',
                  const Color(0xFFEF4E4E)),
            ],
          ),
        );
      },
    );
  }

  Widget _txRow(IconData icon, String label, String amount, Color color) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
              radius: 14,
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(icon, color: color, size: 15)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 13))),
          Text(amount,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _artFraud() {
    return AnimatedBuilder(
      animation: _ambient,
      builder: (_, __) {
        final pulse = 0.92 + 0.08 * math.sin(_ambient.value * math.pi * 2);
        return SizedBox(
          height: 240,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 190 * pulse,
                  height: 190 * pulse,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentA.withValues(alpha: 0.10),
                  ),
                ),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [_accentA, _accentB]),
                    boxShadow: [
                      BoxShadow(
                          color: _accentA.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: 4)
                    ],
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: Colors.white, size: 66),
                ),
                Positioned(
                  bottom: 34,
                  right: 96,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Color(0xFF1FA96A), shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
