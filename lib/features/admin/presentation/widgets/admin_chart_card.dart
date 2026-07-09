import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../fraud_detection/domain/chart_data.dart';

/// A titled card wrapping a single [MonthPoint]-series chart — shared by
/// every Admin Dashboard/Analytics chart (User Growth, Daily Active Users,
/// Monthly Registrations) instead of one bespoke widget class per chart
/// (the pattern `reports/presentation/widgets/*_chart.dart` uses), since
/// they're all the same shape: a label + a single numeric series.
class AdminChartCard extends StatelessWidget {
  final String title;
  final List<MonthPoint> points;
  final Color color;
  final bool bars;

  const AdminChartCard({
    super.key,
    required this.title,
    required this.points,
    required this.color,
    this.bars = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxY =
        (points.map((p) => p.value).fold<double>(0, (a, b) => a > b ? a : b)) *
            1.25;
    final effectiveMaxY = maxY <= 0 ? 10.0 : maxY;

    Widget titleFor(double v, TitleMeta m) {
      final i = v.toInt();
      if (i < 0 || i >= points.length) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(points[i].label,
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
      );
    }

    final titlesData = FlTitlesData(
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: true, getTitlesWidget: titleFor)),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: bars
                ? BarChart(BarChartData(
                    maxY: effectiveMaxY,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: titlesData,
                    barGroups: [
                      for (var i = 0; i < points.length; i++)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                              toY: points[i].value,
                              color: color,
                              width: 16,
                              borderRadius: BorderRadius.circular(4)),
                        ]),
                    ],
                  ))
                : LineChart(LineChartData(
                    minY: 0,
                    maxY: effectiveMaxY,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: titlesData,
                    lineTouchData: LineTouchData(
                      touchTooltipData:
                          LineTouchTooltipData(getTooltipColor: (_) => color),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].value)
                        ],
                        isCurved: true,
                        color: color,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                            show: true, color: color.withValues(alpha: 0.12)),
                      ),
                    ],
                  )),
          ),
        ],
      ),
    );
  }
}
