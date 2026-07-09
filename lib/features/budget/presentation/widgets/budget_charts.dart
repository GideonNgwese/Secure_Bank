import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/constants.dart';
import '../../../fraud_detection/domain/chart_data.dart';
import '../../domain/budget_chart_data.dart';

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

const _palette = [
  AppTokens.brand,
  AppTokens.accent,
  Color(0xFFE0218A),
  Color(0xFF00B4DB),
  AppTokens.success,
  AppTokens.warning,
];

/// 1) Category spending — how much has gone to each budgeted category.
class BudgetCategorySpendingChart extends StatelessWidget {
  final List<CategorySlice> slices;
  const BudgetCategorySpendingChart({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (slices.isEmpty) {
      return _ChartCard(
        title: 'Category spending',
        child: SizedBox(
          height: 100,
          child: Center(
            child: Text('No spending recorded yet.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ),
        ),
      );
    }
    final total = slices.fold<double>(0, (s, c) => s + c.amount);
    return _ChartCard(
      title: 'Category spending',
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 170,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    for (var i = 0; i < slices.length; i++)
                      PieChartSectionData(
                        value: slices[i].amount,
                        color: _palette[i % _palette.length],
                        title:
                            '${(slices[i].amount / total * 100).toStringAsFixed(0)}%',
                        radius: 48,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < slices.length && i < 6; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: _palette[i % _palette.length],
                                borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(slices[i].category,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 2) Budget vs actual — grouped bars per budget.
class BudgetVsActualChart extends StatelessWidget {
  final List<BudgetVsActualPoint> points;
  const BudgetVsActualChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (points.isEmpty) {
      return _ChartCard(
        title: 'Budget vs actual',
        child: SizedBox(
          height: 100,
          child: Center(
              child: Text('Create a budget to see this chart.',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))),
        ),
      );
    }
    var maxY = 0.0;
    for (final p in points) {
      maxY = [maxY, p.budgeted, p.actual].reduce((a, b) => a > b ? a : b);
    }
    return _ChartCard(
      title: 'Budget vs actual',
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            maxY: maxY <= 0 ? 1000 : maxY * 1.25,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= points.length)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(points[i].name,
                          style: TextStyle(
                              fontSize: 9, color: scheme.onSurfaceVariant)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                      toY: points[i].budgeted,
                      color: AppTokens.brand.withValues(alpha: 0.35),
                      width: 10,
                      borderRadius: BorderRadius.circular(3)),
                  BarChartRodData(
                      toY: points[i].actual,
                      color: points[i].actual > points[i].budgeted
                          ? AppColors.critical
                          : AppTokens.brand,
                      width: 10,
                      borderRadius: BorderRadius.circular(3)),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3) Monthly trends — total spend across the last 6 months (reuses the
/// Fraud module's generic month-series builder over raw transactions).
class BudgetMonthlyTrendsChart extends StatelessWidget {
  final List<MonthPoint> points;
  const BudgetMonthlyTrendsChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY =
        (points.map((p) => p.value).fold<double>(0, (a, b) => a > b ? a : b)) *
            1.25;
    return _ChartCard(
      title: 'Monthly trends',
      child: SizedBox(
        height: 190,
        child: BarChart(
          BarChartData(
            maxY: maxY <= 0 ? 1000 : maxY,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= points.length)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(points[i].label,
                          style: TextStyle(
                              fontSize: 10, color: scheme.onSurfaceVariant)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                      toY: points[i].value,
                      color: AppTokens.brand,
                      width: 16,
                      borderRadius: BorderRadius.circular(4)),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4) Savings growth — cumulative savings over the last 6 months (reuses the
/// Fraud module's generic month-series builder).
class BudgetSavingsGrowthChart extends StatelessWidget {
  final List<MonthPoint> points;
  const BudgetSavingsGrowthChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = points.map((p) => p.value).toList();
    final minY = (values.fold<double>(0, (a, b) => a < b ? a : b)) * 1.2;
    final maxY = (values.fold<double>(0, (a, b) => a > b ? a : b)) * 1.2;
    return _ChartCard(
      title: 'Savings growth',
      child: SizedBox(
        height: 170,
        child: LineChart(
          LineChartData(
            minY: minY == 0 ? -1000 : minY,
            maxY: maxY == 0 ? 1000 : maxY,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= points.length)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(points[i].label,
                          style: TextStyle(
                              fontSize: 10, color: scheme.onSurfaceVariant)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++)
                    FlSpot(i.toDouble(), points[i].value)
                ],
                isCurved: true,
                color: AppTokens.success,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                    show: true,
                    color: AppTokens.success.withValues(alpha: 0.14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 5) Remaining budget — how much headroom is left per budget.
class BudgetRemainingChart extends StatelessWidget {
  final List<CategorySlice> slices;
  const BudgetRemainingChart({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (slices.isEmpty) {
      return _ChartCard(
        title: 'Remaining budget',
        child: SizedBox(
          height: 100,
          child: Center(
              child: Text('No budget headroom to show right now.',
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 12))),
        ),
      );
    }
    final top = slices.take(6).toList();
    final maxY =
        top.fold<double>(0, (s, c) => c.amount > s ? c.amount : s) * 1.25;
    return _ChartCard(
      title: 'Remaining budget',
      child: SizedBox(
        height: 190,
        child: BarChart(
          BarChartData(
            maxY: maxY <= 0 ? 1000 : maxY,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= top.length)
                      return const SizedBox.shrink();
                    final label = top[i].category;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                          label.length > 8
                              ? '${label.substring(0, 7)}…'
                              : label,
                          style: TextStyle(
                              fontSize: 9, color: scheme.onSurfaceVariant)),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < top.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                      toY: top[i].amount,
                      color: AppTokens.success,
                      width: 16,
                      borderRadius: BorderRadius.circular(4)),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}
