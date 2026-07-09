import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Shimmering placeholder shown while the report's first data load is in
/// flight, so the dashboard never jump-cuts from blank to full.
class ReportSkeleton extends StatefulWidget {
  const ReportSkeleton({super.key});

  @override
  State<ReportSkeleton> createState() => _ReportSkeletonState();
}

class _ReportSkeletonState extends State<ReportSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = 0.35 + 0.25 * _c.value;
        Widget block(double height) => Container(
              height: height,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: t),
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              ),
            );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            block(180),
            block(60),
            block(220),
            block(200),
            block(200),
          ],
        );
      },
    );
  }
}
