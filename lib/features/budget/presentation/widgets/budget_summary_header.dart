import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/constants.dart';
import '../../domain/budget_summary.dart';

/// The "Home Budget Dashboard" — a premium gradient summary card showing
/// total budget/spent/remaining with count-up animations, monthly progress,
/// savings this month, the Budget Health Score, and an overspending banner.
class BudgetSummaryHeader extends StatelessWidget {
  final BudgetSummary summary;
  const BudgetSummaryHeader({super.key, required this.summary});

  Color get _healthColor => switch (summary.health.label) {
        'Excellent' => AppTokens.success,
        'Good' => Colors.white,
        'Fair' => AppTokens.warning,
        _ => AppTokens.warning,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTokens.brandDeep, AppTokens.brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: [
          BoxShadow(
              color: AppTokens.brandDeep.withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total budget this period',
              style: TextStyle(color: Colors.white70, fontSize: 12.5)),
          const SizedBox(height: 6),
          _countUp(summary.totalBudget, fontSize: 30),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniStat('Spent', summary.totalSpent, Icons.south_west_rounded,
                  const Color(0xFFFF8A8A)),
              _divider(),
              _miniStat(
                  'Remaining',
                  summary.totalRemaining,
                  Icons.account_balance_wallet_outlined,
                  const Color(0xFF9BD1FF)),
              _divider(),
              _miniStat('Saved this month', summary.savingsThisMonth,
                  Icons.savings_outlined, const Color(0xFF4ADE80)),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('Monthly progress',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              const Spacer(),
              Text('${summary.percentUsed.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween:
                  Tween(begin: 0, end: (summary.percentUsed / 100).clamp(0, 1)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => LinearProgressIndicator(
                value: t,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_rounded, size: 13, color: _healthColor),
                    const SizedBox(width: 5),
                    Text(
                        summary.health.score == null
                            ? 'No active budgets'
                            : 'Health: ${summary.health.score} · ${summary.health.label}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (summary.overspendingCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 13, color: Color(0xFFFF8A8A)),
                      const SizedBox(width: 5),
                      Text('${summary.overspendingCount} overspending',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countUp(double value, {required double fontSize}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(formatFCFA(v),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 34, color: Colors.white.withValues(alpha: 0.14));

  Widget _miniStat(String label, double value, IconData icon, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 10.5)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(formatFCFA(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
