import '../../budget/domain/budget_view.dart';

/// The "Budget Performance Report" figures — built directly from the Budget
/// module's own [BudgetWithProgress] (already-computed live spend), so
/// nothing here recomputes spending independently.
class BudgetPerformance {
  final double totalBudgeted;
  final double totalUsed;
  final double totalRemaining;
  final int exceededCount;
  final int successfulCount; // finished within budget
  final List<BudgetWithProgress> budgets;

  const BudgetPerformance({
    required this.totalBudgeted,
    required this.totalUsed,
    required this.totalRemaining,
    required this.exceededCount,
    required this.successfulCount,
    required this.budgets,
  });

  static BudgetPerformance build(List<BudgetWithProgress> budgets) {
    final relevant = budgets.where((b) => b.budget.isActive).toList();
    final totalBudgeted =
        relevant.fold<double>(0, (s, b) => s + b.budget.budgetAmount);
    final totalUsed = relevant.fold<double>(0, (s, b) => s + b.spentAmount);
    final exceeded =
        relevant.where((b) => b.tier == BudgetRiskTier.exceeded).length;
    final successful = relevant
        .where((b) => b.isEnded && b.tier != BudgetRiskTier.exceeded)
        .length;

    return BudgetPerformance(
      totalBudgeted: totalBudgeted,
      totalUsed: totalUsed,
      totalRemaining: totalBudgeted - totalUsed,
      exceededCount: exceeded,
      successfulCount: successful,
      budgets: relevant,
    );
  }
}
