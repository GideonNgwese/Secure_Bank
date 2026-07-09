import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/chart_data.dart';

/// Shared card chrome for every chart in the Fraud Center, so they read as
/// one consistent system (rounded, soft-shadowed, theme-aware).
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

Widget _monthTitle(double value, List<MonthPoint> points, ColorScheme scheme) {
  final i = value.toInt();
  if (i < 0 || i >= points.length) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(points[i].label,
        style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
  );
}

/// 1) Monthly spending — last 6 months of total expenses.
class MonthlySpendingChart extends StatelessWidget {
  final List<MonthPoint> points;
  const MonthlySpendingChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY =
        (points.map((p) => p.value).fold<double>(0, (a, b) => a > b ? a : b)) *
            1.25;
    return _ChartCard(
      title: 'Monthly spending',
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
                  getTitlesWidget: (v, m) => _monthTitle(v, points, scheme),
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

/// 2) Category breakdown — this month's expenses by category.
class CategoryBreakdownChart extends StatelessWidget {
  final List<CategorySlice> slices;
  const CategoryBreakdownChart({super.key, required this.slices});

  static const _palette = [
    AppTokens.brand,
    AppTokens.accent,
    Color(0xFFE0218A),
    Color(0xFF00B4DB),
    AppTokens.success,
    AppTokens.warning,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (slices.isEmpty) {
      return _ChartCard(
        title: 'Category breakdown',
        child: SizedBox(
          height: 100,
          child: Center(
            child: Text('No expenses recorded this month.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
          ),
        ),
      );
    }
    final total = slices.fold<double>(0, (s, c) => s + c.amount);
    return _ChartCard(
      title: 'Category breakdown',
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

/// 3) Income vs expense — last 6 months, grouped bars.
class IncomeVsExpenseChart extends StatelessWidget {
  final List<IncomeExpensePoint> points;
  const IncomeVsExpenseChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var maxY = 0.0;
    for (final p in points) {
      maxY = [maxY, p.income, p.expense].reduce((a, b) => a > b ? a : b);
    }
    if (maxY == 0) maxY = 1000;
    return _ChartCard(
      title: 'Income vs expense',
      child: SizedBox(
        height: 190,
        child: BarChart(
          BarChartData(
            maxY: maxY * 1.25,
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
                    final monthPoints =
                        points.map((p) => MonthPoint(p.label, 0)).toList();
                    return _monthTitle(v, monthPoints, scheme);
                  },
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < points.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                      toY: points[i].income,
                      color: AppTokens.success,
                      width: 7,
                      borderRadius: BorderRadius.circular(3)),
                  BarChartRodData(
                      toY: points[i].expense,
                      color: AppTokens.danger,
                      width: 7,
                      borderRadius: BorderRadius.circular(3)),
                ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4) Risk trend — weekly fraud-alert count over the last 8 weeks.
class RiskTrendChart extends StatelessWidget {
  final List<WeekRiskPoint> points;
  const RiskTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY =
        (points.map((p) => p.alertCount).fold<int>(0, (a, b) => a > b ? a : b) +
                1)
            .toDouble();
    return _ChartCard(
      title: 'Risk trend (weekly alerts)',
      child: SizedBox(
        height: 170,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
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
                  interval:
                      (points.length / 4).clamp(1, points.length).toDouble(),
                  getTitlesWidget: (v, m) {
                    final i = v.toInt();
                    if (i < 0 || i >= points.length)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(points[i].label,
                          style: TextStyle(
                              fontSize: 9, color: scheme.onSurfaceVariant)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++)
                    FlSpot(i.toDouble(), points[i].alertCount.toDouble()),
                ],
                isCurved: true,
                color: AppTokens.danger,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                    show: true,
                    color: AppTokens.danger.withValues(alpha: 0.12)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 5) Savings growth — cumulative net savings over the last 6 months.
class SavingsGrowthChart extends StatelessWidget {
  final List<MonthPoint> points;
  const SavingsGrowthChart({super.key, required this.points});

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
                  getTitlesWidget: (v, m) => _monthTitle(v, points, scheme),
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var i = 0; i < points.length; i++)
                    FlSpot(i.toDouble(), points[i].value),
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
