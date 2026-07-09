import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/constants.dart';
import '../../domain/financial_health.dart';

/// Animated circular gauge for the 0-100 financial health score, with a
/// breakdown of the factors that make it up underneath.
class HealthScoreGauge extends StatelessWidget {
  final FinancialHealthResult result;
  const HealthScoreGauge({super.key, required this.result});

  Color get _color => switch (result.label) {
        'Excellent' => AppTokens.success,
        'Good' => AppTokens.brand,
        'Fair' => AppTokens.warning,
        _ => AppTokens.danger,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: result.score / 100),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 96,
                        height: 96,
                        child: CircularProgressIndicator(
                          value: t,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          color: _color,
                          backgroundColor:
                              scheme.outlineVariant.withValues(alpha: 0.25),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${(t * 100).round()}',
                              style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: _color)),
                          Text('/ 100',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financial health',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(result.label,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _color)),
                    const SizedBox(height: 4),
                    Text(
                      'Based on savings, budgets, income steadiness, debt and how '
                      'consistent your recent activity has been.',
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                          height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _moneyStat(context, 'Income this month', result.income,
                      AppTokens.success)),
              const SizedBox(width: 12),
              Expanded(
                  child: _moneyStat(context, 'Expenses this month',
                      result.expense, AppTokens.danger)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          for (final f in result.factors) _factorRow(context, f),
        ],
      ),
    );
  }

  Widget _moneyStat(
      BuildContext context, String label, double amount, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(formatFCFA(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _factorRow(BuildContext context, FinancialHealthFactor f) {
    final scheme = Theme.of(context).colorScheme;
    final pct = (f.points / f.maxPoints).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(f.label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text('${f.points.round()}/${f.maxPoints.round()}',
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 700),
              builder: (context, t, _) => LinearProgressIndicator(
                value: t,
                minHeight: 6,
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.2),
                color: _color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(f.detail,
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
