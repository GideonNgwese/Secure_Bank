import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/constants.dart';
import '../../../fraud_detection/domain/chart_data.dart';
import '../../../fraud_detection/presentation/widgets/insight_charts.dart'
    show RiskTrendChart;
import '../../domain/fraud_summary.dart';
import 'report_card.dart';

/// Fraud Summary Report: alert counts, risk-level breakdown, resolved vs
/// open, suspicious transaction count, and the risk trend chart (reused
/// as-is from the Fraud Detection module).
class FraudSummarySection extends StatelessWidget {
  final FraudSummary summary;
  final List<WeekRiskPoint> trend;
  const FraudSummarySection(
      {super.key, required this.summary, required this.trend});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReportCard(
          title: 'Fraud & risk summary',
          child: Column(
            children: [
              Row(
                children: [
                  _stat(context, 'Total alerts', '${summary.totalAlerts}',
                      AppTokens.brand),
                  const SizedBox(width: 10),
                  _stat(context, 'Resolved', '${summary.resolvedCount}',
                      AppTokens.success),
                  const SizedBox(width: 10),
                  _stat(
                      context,
                      'Suspicious tx',
                      '${summary.suspiciousTransactionCount}',
                      AppTokens.warning),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _riskRow(context, 'Low', summary.lowCount, AppTokens.brand),
              _riskRow(
                  context, 'Medium', summary.mediumCount, AppTokens.warning),
              _riskRow(context, 'High', summary.highCount, AppTokens.danger),
              _riskRow(context, 'Critical', summary.criticalCount,
                  AppColors.critical,
                  last: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RiskTrendChart(points: trend),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 3),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _riskRow(BuildContext context, String label, int count, Color color,
      {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
              child: Text('$label risk', style: const TextStyle(fontSize: 13))),
          Text('$count',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
