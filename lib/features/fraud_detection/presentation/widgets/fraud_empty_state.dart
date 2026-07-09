import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Shown in the timeline section when there are no alerts or insights yet.
/// The "all clear" icon pops in with an explicit [ScaleTransition] — a
/// little celebratory beat for what is, after all, good news.
class FraudEmptyState extends StatefulWidget {
  const FraudEmptyState({super.key});

  @override
  State<FraudEmptyState> createState() => _FraudEmptyStateState();
}

class _FraudEmptyStateState extends State<FraudEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500))
    ..forward();
  late final Animation<double> _scale =
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTokens.success.withValues(alpha: 0.14),
                    AppTokens.brand.withValues(alpha: 0.14),
                  ],
                ),
              ),
              child: const Icon(Icons.verified_user_outlined,
                  color: AppTokens.success, size: 32),
            ),
          ),
          const SizedBox(height: 16),
          const Text('All clear',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'No risk alerts right now. Insights will appear here as you record\nmore transactions.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }
}
