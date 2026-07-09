import '../../../models/transaction_model.dart';
import '../../../utils/constants.dart';
import 'budget_view.dart';

class BudgetInsight {
  final String title;
  final String message;
  final String sentiment; // positive / neutral / warning

  const BudgetInsight(
      {required this.title, required this.message, this.sentiment = 'neutral'});
}

/// Generates the budget module's smart insights — live-computed each time
/// the screen builds (cheap: it's a handful of already-fetched lists), not
/// persisted. Budget *alerts* (80%/90%/exceeded/ending-soon) are a separate,
/// persisted concern handled by `FirestoreService.checkBudgetAfterTransaction`
/// — this engine is purely advisory, shown inline in the Budget module's UI.
class BudgetInsightsEngine {
  BudgetInsightsEngine._();

  static List<BudgetInsight> generate({
    required List<BudgetWithProgress> activeBudgets,
    required List<TransactionModel> allTx,
    required DateTime now,
  }) {
    final insights = <BudgetInsight>[];
    insights.addAll(_usageThresholds(activeBudgets));
    insights.addAll(_exceeded(activeBudgets));
    insights.addAll(_projectedOverspend(activeBudgets));
    insights.addAll(_categoryTrends(activeBudgets, allTx, now));
    final savings = _savingsProjection(allTx, now);
    if (savings != null) insights.add(savings);
    return insights;
  }

  /// "You have used 72% of your Food budget."
  static List<BudgetInsight> _usageThresholds(
      List<BudgetWithProgress> budgets) {
    return budgets
        .where((b) => b.percentUsed >= 70 && b.percentUsed <= 100)
        .map((b) => BudgetInsight(
              title:
                  '${b.budget.category} budget at ${b.percentUsed.toStringAsFixed(0)}%',
              message:
                  'You have used ${b.percentUsed.toStringAsFixed(0)}% of your ${b.budget.category} budget.',
              sentiment: b.percentUsed >= 85 ? 'warning' : 'neutral',
            ))
        .toList();
  }

  /// "Entertainment spending exceeded your budget."
  static List<BudgetInsight> _exceeded(List<BudgetWithProgress> budgets) {
    return budgets
        .where((b) => b.tier == BudgetRiskTier.exceeded)
        .map((b) => BudgetInsight(
              title: '${b.budget.category} budget exceeded',
              message: '${b.budget.category} spending exceeded your budget '
                  '(${formatFCFA(b.spentAmount)} of ${formatFCFA(b.budget.budgetAmount)}).',
              sentiment: 'warning',
            ))
        .toList();
  }

  /// "You may exceed your Shopping budget within 5 days."
  static List<BudgetInsight> _projectedOverspend(
      List<BudgetWithProgress> budgets) {
    return budgets.where((b) => b.isProjectedToExceed).map((b) {
      final days = b.daysUntilProjectedExceed ?? 0;
      return BudgetInsight(
        title: '${b.budget.category} trending over budget',
        message: days <= 0
            ? 'You may exceed your ${b.budget.category} budget very soon at this rate.'
            : 'You may exceed your ${b.budget.category} budget within $days day${days == 1 ? '' : 's'}.',
        sentiment: 'warning',
      );
    }).toList();
  }

  /// "Transport expenses are increasing."
  static List<BudgetInsight> _categoryTrends(List<BudgetWithProgress> budgets,
      List<TransactionModel> allTx, DateTime now) {
    final last = DateTime(now.year, now.month - 1);
    final results = <BudgetInsight>[];

    for (final b in budgets) {
      final thisMonth = allTx
          .where((t) =>
              t.type == 'Expense' &&
              t.isCompleted &&
              t.category == b.budget.category &&
              t.transactionDate.year == now.year &&
              t.transactionDate.month == now.month)
          .fold<double>(0, (s, t) => s + t.amount);
      final lastMonth = allTx
          .where((t) =>
              t.type == 'Expense' &&
              t.isCompleted &&
              t.category == b.budget.category &&
              t.transactionDate.year == last.year &&
              t.transactionDate.month == last.month)
          .fold<double>(0, (s, t) => s + t.amount);
      if (lastMonth < 2000) continue;
      final change = (thisMonth - lastMonth) / lastMonth * 100;
      if (change < 15) continue; // only flag meaningful increases
      results.add(BudgetInsight(
        title: '${b.budget.category} trending up',
        message: '${b.budget.category} expenses are increasing '
            '(+${change.toStringAsFixed(0)}% vs last month).',
        sentiment: 'warning',
      ));
    }
    return results.take(2).toList();
  }

  /// "You are on track to save 45,000 FCFA this month."
  static BudgetInsight? _savingsProjection(
      List<TransactionModel> allTx, DateTime now) {
    final monthTx = allTx.where((t) =>
        t.isCompleted &&
        t.transactionDate.year == now.year &&
        t.transactionDate.month == now.month);
    final income = monthTx
        .where((t) => t.type == 'Income' || t.type == 'Refund')
        .fold<double>(0, (s, t) => s + t.amount);
    final expenseSoFar = monthTx
        .where((t) => t.type == 'Expense')
        .fold<double>(0, (s, t) => s + t.amount);
    if (income <= 0) return null;

    final daysElapsed = now.day.clamp(1, 28);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final projectedExpense = expenseSoFar / daysElapsed * daysInMonth;
    final projectedSavings = income - projectedExpense;
    if (projectedSavings <= 0) return null;

    return BudgetInsight(
      title: 'On track to save this month',
      message:
          'You are on track to save ${formatFCFA(projectedSavings)} this month.',
      sentiment: 'positive',
    );
  }
}
