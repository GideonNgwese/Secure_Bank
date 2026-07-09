import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../fraud_detection/domain/chart_data.dart';
import 'report_card.dart';

/// Monthly Spending Trend — a line graph over the last 6 months (Jan, Feb,
/// Mar... style labels), independent of the report's own date filter.
class SpendingTrendChart extends StatelessWidget {
  final List<MonthPoint> points;
  const SpendingTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxY =
        (points.map((p) => p.value).fold<double>(0, (a, b) => a > b ? a : b)) *
            1.25;
    return ReportCard(
      title: 'Monthly spending trend',
      child: SizedBox(
        height: 190,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY <= 0 ? 1000 : maxY,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppTokens.brandDeep,
              ),
            ),
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
                color: AppTokens.danger,
                barWidth: 3,
                dotData: const FlDotData(show: true),
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
