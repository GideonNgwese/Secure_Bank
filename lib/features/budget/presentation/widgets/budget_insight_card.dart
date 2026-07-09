import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/budget_insights.dart';

/// A single smart-insight row (budget usage, trend, projected overspend,
/// savings projection) shown inline in the Budget dashboard.
class BudgetInsightCard extends StatelessWidget {
  final BudgetInsight insight;
  const BudgetInsightCard({super.key, required this.insight});

  ({Color color, IconData icon}) get _style => switch (insight.sentiment) {
        'positive' => (
            color: AppTokens.success,
            icon: Icons.trending_up_rounded
          ),
        'warning' => (color: AppTokens.warning, icon: Icons.info_outline),
        _ => (color: AppTokens.brand, icon: Icons.lightbulb_outline),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _style;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.14),
                shape: BoxShape.circle),
            child: Icon(style.icon, color: style.color, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(insight.message,
                style: const TextStyle(fontSize: 12.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
