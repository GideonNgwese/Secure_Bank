import '../../../models/transaction_model.dart';
import '../../fraud_detection/domain/chart_data.dart'
    show CategorySlice, MonthPoint;

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

/// Chart data scoped to the report's *selected* date range — distinct from
/// `fraud_detection`'s `ChartDataBuilder`, whose month/week trend series are
/// deliberately always "the last N calendar months/weeks" regardless of any
/// filter (that's what makes them trend charts). This one answers "what did
/// the user spend, in the exact window they picked" — plus one more trend
/// series (income) that the Fraud module's builder doesn't have.
class ReportChartData {
  ReportChartData._();

  static List<CategorySlice> expenseByCategory(
      List<TransactionModel> periodTx) {
    final byCat = <String, double>{};
    for (final t
        in periodTx.where((t) => t.type == 'Expense' && t.isCompleted)) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    final slices = byCat.entries
        .map((e) => CategorySlice(e.key, e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return slices;
  }

  static List<CategorySlice> incomeBySource(List<TransactionModel> periodTx) {
    final byCat = <String, double>{};
    for (final t
        in periodTx.where((t) => t.type == 'Income' && t.isCompleted)) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    final slices = byCat.entries
        .map((e) => CategorySlice(e.key, e.value))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return slices;
  }

  /// Income — last 6 months (a fixed trend window, same reasoning as the
  /// Fraud module's month-series builders).
  static List<MonthPoint> incomeTrend(List<TransactionModel> tx, DateTime now) {
    return [
      for (var i = 5; i >= 0; i--)
        () {
          final m = DateTime(now.year, now.month - i);
          final total = tx
              .where((t) =>
                  t.type == 'Income' &&
                  t.isCompleted &&
                  t.transactionDate.year == m.year &&
                  t.transactionDate.month == m.month)
              .fold<double>(0, (s, t) => s + t.amount);
          return MonthPoint(_months[m.month - 1], total);
        }(),
    ];
  }
}
