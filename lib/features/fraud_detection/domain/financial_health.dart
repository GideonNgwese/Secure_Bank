/// One weighted contributor to the overall financial health score.
class FinancialHealthFactor {
  final String label;
  final double points; // points actually earned
  final double maxPoints;
  final String detail;

  const FinancialHealthFactor({
    required this.label,
    required this.points,
    required this.maxPoints,
    required this.detail,
  });
}

class FinancialHealthResult {
  final int score; // 0-100
  final String label; // Excellent / Good / Fair / Needs Improvement
  final List<FinancialHealthFactor> factors;
  final double income; // this month, for display alongside the score
  final double expense; // this month, for display alongside the score

  const FinancialHealthResult({
    required this.score,
    required this.label,
    required this.factors,
    required this.income,
    required this.expense,
  });

  static String labelFor(int score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Improvement';
  }
}

/// Computes a 0-100 financial health score from the same signals a personal
/// finance coach would look at: how much you save, whether you stay within
/// budget, how steady your income is, how debt-loaded you are, and how
/// often your own activity gets fraud-flagged. Pure function — no
/// Firestore, easy to unit test.
class FinancialHealthCalculator {
  FinancialHealthCalculator._();

  static FinancialHealthResult compute({
    required double income,
    required double expense,
    required double avgBudgetUsagePct, // null-safe: pass 50 if no budgets set
    required bool hasBudgets,
    required double debtRatio, // Loan-category expense / income, 0+
    required int monthsWithIncome, // out of the last 3
    required double flaggedRatio, // fraud-flagged txs / total txs this period
  }) {
    final factors = <FinancialHealthFactor>[];

    // Savings rate — up to 30 pts, full marks at a 30%+ savings rate.
    final savingsRate = income > 0 ? ((income - expense) / income) : 0.0;
    final savingsPoints = (savingsRate / 0.30 * 30).clamp(0, 30).toDouble();
    factors.add(FinancialHealthFactor(
      label: 'Savings rate',
      points: savingsPoints,
      maxPoints: 30,
      detail: income > 0
          ? '${(savingsRate * 100).toStringAsFixed(0)}% of income saved this month'
          : 'No income recorded this month',
    ));

    // Budget adherence — up to 20 pts. No budgets tracked = neutral half credit.
    final budgetPoints = hasBudgets
        ? ((100 - avgBudgetUsagePct) / 100 * 20).clamp(0, 20).toDouble()
        : 10.0;
    factors.add(FinancialHealthFactor(
      label: 'Budget adherence',
      points: budgetPoints,
      maxPoints: 20,
      detail: hasBudgets
          ? '${avgBudgetUsagePct.toStringAsFixed(0)}% average budget usage'
          : 'No budgets set yet',
    ));

    // Income consistency — up to 15 pts for income in each of the last 3 months.
    final incomePoints = (monthsWithIncome / 3 * 15).clamp(0, 15).toDouble();
    factors.add(FinancialHealthFactor(
      label: 'Income consistency',
      points: incomePoints,
      maxPoints: 15,
      detail: '$monthsWithIncome of the last 3 months had recorded income',
    ));

    // Debt ratio — up to 15 pts, full marks at 0% loan spend vs income.
    final debtPoints = (15 - debtRatio.clamp(0, 1) * 15).toDouble();
    factors.add(FinancialHealthFactor(
      label: 'Debt ratio',
      points: debtPoints,
      maxPoints: 15,
      detail:
          '${(debtRatio * 100).clamp(0, 999).toStringAsFixed(0)}% of income went to loan repayments',
    ));

    // Transaction consistency — up to 20 pts, penalized by how often
    // activity gets fraud-flagged (a proxy for erratic/risky behaviour).
    final consistencyPoints =
        (20 - (flaggedRatio * 4 * 20).clamp(0, 20)).toDouble();
    factors.add(FinancialHealthFactor(
      label: 'Transaction consistency',
      points: consistencyPoints,
      maxPoints: 20,
      detail: flaggedRatio > 0
          ? '${(flaggedRatio * 100).toStringAsFixed(0)}% of transactions were flagged'
          : 'No flagged transactions recently',
    ));

    final score =
        factors.fold<double>(0, (s, f) => s + f.points).round().clamp(0, 100);
    return FinancialHealthResult(
      score: score,
      label: FinancialHealthResult.labelFor(score),
      factors: factors,
      income: income,
      expense: expense,
    );
  }
}
