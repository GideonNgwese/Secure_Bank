import '../../fraud_detection/domain/chart_data.dart';
import 'budget_performance.dart';
import 'fraud_summary.dart';
import 'income_analytics.dart';
import 'report_summary.dart';

/// Plain-language recommendations for the report's summary/PDF footer —
/// generated from the same figures already computed for the dashboard, not
/// a second analysis pass.
class ReportRecommendations {
  ReportRecommendations._();

  static List<String> generate({
    required ReportSummary summary,
    required IncomeAnalytics income,
    required List<CategorySlice> expenseByCategory,
    required BudgetPerformance budgets,
    required FraudSummary fraud,
  }) {
    final tips = <String>[];

    if (summary.totalIncome > 0) {
      if (summary.savingsRate < 10) {
        tips.add(
            'Your savings rate is ${summary.savingsRate.toStringAsFixed(0)}% — try to keep '
            'monthly savings above 10-20% of income for a healthier cushion.');
      } else if (summary.savingsRate >= 20) {
        tips.add(
            'Great work — you saved ${summary.savingsRate.toStringAsFixed(0)}% of your '
            'income this period. Keep it up.');
      }
    }

    if (income.previousTotalIncome > 0 && income.growthPct < -5) {
      tips.add(
          'Income dropped ${income.growthPct.abs().toStringAsFixed(0)}% compared to the '
          'previous period — worth reviewing your income sources.');
    }

    if (expenseByCategory.isNotEmpty) {
      final total = expenseByCategory.fold<double>(0, (s, c) => s + c.amount);
      final top = expenseByCategory.first;
      if (total > 0 && top.amount / total > 0.4) {
        tips.add(
            '${top.category} makes up ${(top.amount / total * 100).toStringAsFixed(0)}% of '
            'your spending — consider a dedicated budget to keep it in check.');
      }
    }

    if (budgets.exceededCount > 0) {
      tips.add('You exceeded ${budgets.exceededCount} budget'
          '${budgets.exceededCount == 1 ? '' : 's'} this period — review the categories involved '
          'in the Budget tab.');
    } else if (budgets.budgets.isNotEmpty) {
      tips.add('All your active budgets are within limits — nice discipline.');
    }

    if (fraud.openCount > 0) {
      tips.add('You have ${fraud.openCount} unresolved risk alert'
          '${fraud.openCount == 1 ? '' : 's'} — review them in Fraud & Insights.');
    }

    if (tips.isEmpty) {
      tips.add(
          'No major concerns this period — keep tracking your transactions regularly for '
          'the most accurate insights.');
    }
    return tips;
  }
}
