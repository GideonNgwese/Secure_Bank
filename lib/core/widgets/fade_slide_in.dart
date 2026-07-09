import 'package:flutter/material.dart';

/// One-shot fade + upward slide entrance animation (no controller needed).
/// Wrap content that should animate in when a screen first builds.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double offsetY;
  final Curve curve;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 550),
    this.offsetY = 24,
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * offsetY),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
