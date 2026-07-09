import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Shimmering placeholder rows shown while the first page of transactions
/// is loading — avoids a blank screen / spinner jump-cut.
class TransactionSkeleton extends StatefulWidget {
  final int count;
  const TransactionSkeleton({super.key, this.count = 8});

  @override
  State<TransactionSkeleton> createState() => _TransactionSkeletonState();
}

class _TransactionSkeletonState extends State<TransactionSkeleton>
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
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: widget.count,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: t),
              borderRadius: BorderRadius.circular(AppTokens.radius),
            ),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 21,
                    backgroundColor: scheme.onSurface.withValues(alpha: 0.06)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(scheme, width: 120, height: 12),
                      const SizedBox(height: 8),
                      _bar(scheme, width: 160, height: 9),
                    ],
                  ),
                ),
                _bar(scheme, width: 54, height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bar(ColorScheme scheme,
      {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
