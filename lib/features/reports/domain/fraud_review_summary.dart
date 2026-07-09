import '../../../models/transaction_model.dart';

/// Fraud Review Workflow metrics for the Reports screen — reuses the same
/// risk-flagged transaction set [FraudSummary] already draws from, just
/// grouped by review outcome instead of risk level.
class FraudReviewSummary {
  final int pendingReviews;
  final int approved;
  final int blocked; // Declined
  final double averageRiskScore;
  final double resolutionRatePct; // 0-100: share of flagged tx already acted on

  const FraudReviewSummary({
    required this.pendingReviews,
    required this.approved,
    required this.blocked,
    required this.averageRiskScore,
    required this.resolutionRatePct,
  });

  static FraudReviewSummary build(List<TransactionModel> txInRange) {
    final flagged = txInRange.where((t) => t.riskLevel != 'Low').toList();
    final pending = flagged.where((t) => t.isPendingReview).length;
    final approved = flagged.where((t) => t.status == 'Approved').length;
    final declined = flagged.where((t) => t.status == 'Declined').length;
    final avgScore = flagged.isEmpty
        ? 0.0
        : flagged.fold<int>(0, (s, t) => s + t.riskScore) / flagged.length;
    final resolved = approved + declined;
    final resolutionRate =
        flagged.isEmpty ? 0.0 : resolved / flagged.length * 100;

    return FraudReviewSummary(
      pendingReviews: pending,
      approved: approved,
      blocked: declined,
      averageRiskScore: avgScore,
      resolutionRatePct: resolutionRate,
    );
  }
}
