import '../../fraud_detection/domain/chart_data.dart' show CategorySlice;
import 'budget_view.dart';

class BudgetVsActualPoint {
  final String name;
  final double budgeted;
  final double actual;
  const BudgetVsActualPoint(this.name, this.budgeted, this.actual);
}

/// Budget-specific chart series — the generic month/savings series are
/// reused directly from `fraud_detection`'s `ChartDataBuilder` (a pure,
/// stateless utility with no feature-specific coupling), so only the
/// budget-shaped ones (which need `BudgetWithProgress`) live here.
class BudgetChartDataBuilder {
  BudgetChartDataBuilder._();

  static List<CategorySlice> categorySpending(
      List<BudgetWithProgress> budgets) {
    final slices = budgets
        .where((b) => b.spentAmount > 0)
        .map((b) => CategorySlice(b.budget.category, b.spentAmount))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return slices;
  }

  static List<BudgetVsActualPoint> budgetVsActual(
      List<BudgetWithProgress> budgets) {
    return budgets
        .take(6)
        .map((b) => BudgetVsActualPoint(
            b.budget.name.length > 10
                ? '${b.budget.name.substring(0, 9)}…'
                : b.budget.name,
            b.budget.budgetAmount,
            b.spentAmount))
        .toList();
  }

  static List<CategorySlice> remainingBudget(List<BudgetWithProgress> budgets) {
    return budgets
        .where((b) => b.remainingAmount > 0)
        .map((b) => CategorySlice(b.budget.name, b.remainingAmount))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }
}
