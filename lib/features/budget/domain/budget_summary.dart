import 'budget_health.dart';

/// Aggregate figures for the Budget module's "Home Budget Dashboard" header.
class BudgetSummary {
  final double totalBudget;
  final double totalSpent;
  final double totalRemaining;
  final double savingsThisMonth;
  final BudgetHealthResult health;
  final int overspendingCount;
  final int endingSoonCount; // active budgets ending within 3 days

  const BudgetSummary({
    required this.totalBudget,
    required this.totalSpent,
    required this.totalRemaining,
    required this.savingsThisMonth,
    required this.health,
    required this.overspendingCount,
    required this.endingSoonCount,
  });

  double get percentUsed =>
      totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0;
}
