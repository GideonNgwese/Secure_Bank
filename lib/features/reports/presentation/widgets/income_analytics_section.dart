import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/constants.dart';
import '../../../fraud_detection/domain/chart_data.dart';
import '../../domain/income_analytics.dart';
import 'report_card.dart';

const _palette = [
  AppTokens.brand,
  AppTokens.accent,
  Color(0xFF00B4DB),
  AppTokens.success,
  Color(0xFFE0218A),
  AppTokens.warning,
];

/// Income Analytics: sources with amount/%/growth, a bar chart of sources,
/// and a 6-month income line trend.
class IncomeAnalyticsSection extends StatelessWidget {
  final IncomeAnalytics income;
  final List<MonthPoint> trend;
  const IncomeAnalyticsSection(
      {super.key, required this.income, required this.trend});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        ReportCard(
          title: 'Income sources',
          child: income.sources.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No income recorded for this period.',
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < income.sources.length; i++)
                      _sourceRow(context, income.sources[i],
                          _palette[i % _palette.length]),
                  ],
                ),
        ),
        if (income.sources.isNotEmpty) ...[
          const SizedBox(height: 12),
          ReportCard(
            title: 'Income by source',
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: (income.sources
                          .map((s) => s.amount)
                          .reduce((a, b) => a > b ? a : b)) *
                      1.25,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) {
                          final i = v.toInt();
                          if (i < 0 || i >= income.sources.length)
                            return const SizedBox.shrink();
                          final label = income.sources[i].category;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                label.length > 8
                                    ? '${label.substring(0, 7)}…'
                                    : label,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: scheme.onSurfaceVariant)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < income.sources.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                            toY: income.sources[i].amount,
                            color: _palette[i % _palette.length],
                            width: 18,
                            borderRadius: BorderRadius.circular(4)),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ReportCard(
          title: 'Income trend (6 months)',
          child: SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: 0,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= trend.length)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(trend[i].label,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant)),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < trend.length; i++)
                        FlSpot(i.toDouble(), trend[i].value)
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
        ),
      ],
    );
  }

  Widget _sourceRow(BuildContext context, IncomeSource s, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final up = s.growthPct >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(s.category,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Text(formatFCFA(s.amount),
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text('${s.percentage.toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style:
                    TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12, color: up ? AppTokens.success : AppTokens.danger),
              Text('${s.growthPct.abs().toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: up ? AppTokens.success : AppTokens.danger)),
            ],
          ),
        ],
      ),
    );
  }
}
