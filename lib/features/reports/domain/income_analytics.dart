import '../../../models/transaction_model.dart';

class IncomeSource {
  final String category;
  final double amount;
  final double percentage;
  final double growthPct; // vs the previous period of equal length

  const IncomeSource({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.growthPct,
  });
}

class IncomeAnalytics {
  final double totalIncome;
  final double previousTotalIncome;
  final List<IncomeSource> sources;

  const IncomeAnalytics({
    required this.totalIncome,
    required this.previousTotalIncome,
    required this.sources,
  });

  double get growthPct => previousTotalIncome > 0
      ? (totalIncome - previousTotalIncome) / previousTotalIncome * 100
      : 0;
}

/// Breaks income down by source category (Salary, Business, Investment,
/// Other, ...) with each source's share of the total and its growth vs the
/// previous period of equal length.
class IncomeAnalyticsBuilder {
  IncomeAnalyticsBuilder._();

  static IncomeAnalytics build({
    required List<TransactionModel> currentPeriodTx,
    required List<TransactionModel> previousPeriodTx,
  }) {
    double sumByCategory(List<TransactionModel> tx, String category) => tx
        .where((t) =>
            t.type == 'Income' && t.isCompleted && t.category == category)
        .fold<double>(0, (s, t) => s + t.amount);

    final currentIncome =
        currentPeriodTx.where((t) => t.type == 'Income' && t.isCompleted);
    final byCategory = <String, double>{};
    for (final t in currentIncome) {
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }

    final total = byCategory.values.fold<double>(0, (s, v) => s + v);
    final previousTotal = previousPeriodTx
        .where((t) => t.type == 'Income' && t.isCompleted)
        .fold<double>(0, (s, t) => s + t.amount);

    final sources = byCategory.entries
        .map((e) => IncomeSource(
              category: e.key,
              amount: e.value,
              percentage: total > 0 ? e.value / total * 100 : 0,
              growthPct:
                  _growth(e.value, sumByCategory(previousPeriodTx, e.key)),
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return IncomeAnalytics(
        totalIncome: total,
        previousTotalIncome: previousTotal,
        sources: sources);
  }

  static double _growth(double current, double previous) {
    if (previous <= 0) return current > 0 ? 100 : 0;
    return (current - previous) / previous * 100;
  }
}
