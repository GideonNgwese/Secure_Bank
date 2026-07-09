import 'budget_view.dart';

/// Budget-scoped health score (0-100) — distinct from the broader Financial
/// Health Score in the Fraud Detection module (which also weighs income,
/// debt and transaction consistency). This one answers a narrower question:
/// "how well am I pacing against my *current* budgets?" — each active
/// budget is scored on whether its spend-so-far is ahead of or behind how
/// much of its period has elapsed, then averaged.
class BudgetHealthResult {
  final int? score; // null = no active budgets to score
  final String label;
  final int onTrackCount;
  final int atRiskCount;
  final int exceededCount;

  const BudgetHealthResult({
    required this.score,
    required this.label,
    required this.onTrackCount,
    required this.atRiskCount,
    required this.exceededCount,
  });

  static String labelFor(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Improvement';
  }
}

class BudgetHealthCalculator {
  BudgetHealthCalculator._();

  static BudgetHealthResult compute(List<BudgetWithProgress> activeBudgets) {
    if (activeBudgets.isEmpty) {
      return const BudgetHealthResult(
          score: null,
          label: 'No active budgets',
          onTrackCount: 0,
          atRiskCount: 0,
          exceededCount: 0);
    }

    var totalScore = 0.0;
    var onTrack = 0, atRisk = 0, exceeded = 0;
    for (final b in activeBudgets) {
      // Penalize spending faster than the period has elapsed (e.g. 90% spent
      // with only 50% of the period gone is worse than 90% spent at 90%
      // elapsed).
      final paceOverage =
          (b.percentUsed - b.timeElapsedFraction * 100).clamp(0, 100);
      totalScore += (100 - paceOverage).clamp(0, 100);

      switch (b.tier) {
        case BudgetRiskTier.exceeded:
          exceeded++;
        case BudgetRiskTier.critical:
        case BudgetRiskTier.warning:
          atRisk++;
        case BudgetRiskTier.safe:
          onTrack++;
      }
    }

    final score = (totalScore / activeBudgets.length).round().clamp(0, 100);
    return BudgetHealthResult(
      score: score,
      label: BudgetHealthResult.labelFor(score),
      onTrackCount: onTrack,
      atRiskCount: atRisk,
      exceededCount: exceeded,
    );
  }
}
