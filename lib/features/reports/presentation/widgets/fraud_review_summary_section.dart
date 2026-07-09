import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/fraud_review_summary.dart';
import 'report_card.dart';

/// Fraud Review Workflow summary: Pending / Approved / Blocked counts, plus
/// average risk score and resolution rate across this period's flagged
/// transactions. Sits alongside [FraudSummarySection] (risk-level breakdown)
/// rather than replacing it — this is about review *outcomes*, not risk.
class FraudReviewSummarySection extends StatelessWidget {
  final FraudReviewSummary summary;
  const FraudReviewSummarySection({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return ReportCard(
      title: 'Fraud review summary',
      child: Column(
        children: [
          Row(
            children: [
              _stat(context, 'Pending', '${summary.pendingReviews}',
                  AppTokens.warning),
              const SizedBox(width: 10),
              _stat(context, 'Approved', '${summary.approved}',
                  AppTokens.success),
              const SizedBox(width: 10),
              _stat(
                  context, 'Blocked', '${summary.blocked}', AppTokens.danger),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _row(context, 'Average risk score',
              summary.averageRiskScore.toStringAsFixed(0)),
          _row(context, 'Fraud resolution rate',
              '${summary.resolutionRatePct.toStringAsFixed(0)}%',
              last: true),
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

  Widget _row(BuildContext context, String label, String value,
      {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
