import '../../../models/fraud_alert_model.dart';
import '../../../models/transaction_model.dart';

class MonthPoint {
  final String label;
  final double value;
  const MonthPoint(this.label, this.value);
}

class IncomeExpensePoint {
  final String label;
  final double income;
  final double expense;
  const IncomeExpensePoint(this.label, this.income, this.expense);
}

class CategorySlice {
  final String category;
  final double amount;
  const CategorySlice(this.category, this.amount);
}

class WeekRiskPoint {
  final String label;
  final int alertCount;
  final double avgScore;
  const WeekRiskPoint(this.label, this.alertCount, this.avgScore);
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

/// Pure chart-data builders — pre-aggregate transactions/alerts into the
/// small series each fl_chart widget needs, so the widgets themselves stay
/// dumb renderers with no business logic.
class ChartDataBuilder {
  ChartDataBuilder._();

  static bool _inMonth(TransactionModel t, DateTime m) =>
      t.transactionDate.year == m.year &&
      t.transactionDate.month == m.month &&
      t.isCompleted;

  /// Monthly spending — last 6 months of total Expense.
  static List<MonthPoint> monthlySpending(
      List<TransactionModel> tx, DateTime now) {
    return [
      for (var i = 5; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i);
          final total = tx
              .where((t) => t.type == 'Expense' && _inMonth(t, m))
              .fold<double>(0, (s, t) => s + t.amount);
          return MonthPoint(_months[m.month - 1], total);
        }(),
    ];
  }

  /// Income vs expense — last 6 months.
  static List<IncomeExpensePoint> incomeVsExpense(
      List<TransactionModel> tx, DateTime now) {
    return [
      for (var i = 5; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i);
          final monthTx = tx.where((t) => _inMonth(t, m));
          final income = monthTx
              .where((t) => t.type == 'Income' || t.type == 'Refund')
              .fold<double>(0, (s, t) => s + t.amount);
          final expense = monthTx
              .where((t) => t.type == 'Expense')
              .fold<double>(0, (s, t) => s + t.amount);
          return IncomeExpensePoint(_months[m.month - 1], income, expense);
        }(),
    ];
  }

  /// Category breakdown — current month's expenses.
  static List<CategorySlice> categoryBreakdown(
      List<TransactionModel> tx, DateTime now) {
    final byCat = <String, double>{};
    for (final t in tx.where((t) => t.type == 'Expense' && _inMonth(t, now))) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    final slices = byCat.entries
        .map((e) => CategorySlice(e.key, e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return slices;
  }

  /// Savings growth — cumulative (income - expense) across the last 6 months.
  static List<MonthPoint> savingsGrowth(
      List<TransactionModel> tx, DateTime now) {
    var cumulative = 0.0;
    return [
      for (var i = 5; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i);
          final monthTx = tx.where((t) => _inMonth(t, m));
          final net = monthTx
                  .where((t) => t.type == 'Income' || t.type == 'Refund')
                  .fold<double>(0, (s, t) => s + t.amount) -
              monthTx
                  .where((t) => t.type == 'Expense')
                  .fold<double>(0, (s, t) => s + t.amount);
          cumulative += net;
          return MonthPoint(_months[m.month - 1], cumulative);
        }(),
    ];
  }

  /// Risk trend — alert count + average score per week, last 8 weeks.
  static List<WeekRiskPoint> riskTrend(
      List<FraudAlertModel> alerts, DateTime now) {
    return [
      for (var i = 7; i >= 0; i--)
        () {
          final weekStart =
              now.subtract(Duration(days: now.weekday - 1 + i * 7));
          final weekEnd = weekStart.add(const Duration(days: 7));
          final weekAlerts = alerts.where((a) =>
              !a.createdAt.isBefore(weekStart) &&
              a.createdAt.isBefore(weekEnd));
          final count = weekAlerts.length;
          final avg = count == 0
              ? 0.0
              : weekAlerts.fold<int>(0, (s, a) => s + a.riskScore) / count;
          return WeekRiskPoint(
              '${weekStart.day}/${weekStart.month}', count, avg);
        }(),
    ];
  }
}
