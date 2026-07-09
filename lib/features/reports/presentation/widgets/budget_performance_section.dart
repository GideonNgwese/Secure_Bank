import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/constants.dart';
import '../../../budget/domain/budget_view.dart';
import '../../domain/budget_performance.dart';
import 'report_card.dart';

/// Budget Performance Report: used/remaining/exceeded/successful stats plus
/// a per-budget usage list ("Food Budget — 80% used").
class BudgetPerformanceSection extends StatelessWidget {
  final BudgetPerformance performance;
  const BudgetPerformanceSection({super.key, required this.performance});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ReportCard(
      title: 'Budget performance',
      child: Column(
        children: [
          Row(
            children: [
              _stat(context, 'Used', formatFCFA(performance.totalUsed),
                  AppTokens.danger),
              const SizedBox(width: 10),
              _stat(context, 'Remaining',
                  formatFCFA(performance.totalRemaining), AppTokens.success),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat(context, 'Exceeded', '${performance.exceededCount}',
                  AppColors.critical),
              const SizedBox(width: 10),
              _stat(context, 'Successful', '${performance.successfulCount}',
                  AppTokens.brand),
            ],
          ),
          if (performance.budgets.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            for (final b in performance.budgets) _budgetRow(context, b),
          ] else ...[
            const SizedBox(height: 12),
            Text('No active budgets to report on.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 3),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _budgetRow(BuildContext context, BudgetWithProgress b) {
    final scheme = Theme.of(context).colorScheme;
    final tierColor = b.tier.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('${b.budget.name} (${b.budget.category})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Text('${b.percentUsed.toStringAsFixed(0)}% used',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: tierColor)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (b.percentUsed / 100).clamp(0, 1)),
              duration: const Duration(milliseconds: 700),
              builder: (context, t, _) => LinearProgressIndicator(
                value: t,
                minHeight: 6,
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.2),
                color: tierColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
