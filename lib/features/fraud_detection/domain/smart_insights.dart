import '../../../models/transaction_model.dart';
import '../../../utils/constants.dart';

class SmartInsight {
  final String type;
  final String title;
  final String message;
  final String sentiment; // positive / neutral / warning

  const SmartInsight({
    required this.type,
    required this.title,
    required this.message,
    this.sentiment = 'neutral',
  });
}

/// Generates human-readable financial insights by comparing this month's
/// activity against last month's (and, for overspend detection, a trailing
/// 3-month average) — pure function over already-fetched transactions, no
/// Firestore here. [SmartInsightGenerationController] persists whatever
/// comes out of this to `financial_insights` for the Fraud Center's timeline.
class SmartInsightsEngine {
  SmartInsightsEngine._();

  static List<SmartInsight> generate(
      List<TransactionModel> allTx, DateTime now) {
    final insights = <SmartInsight>[];
    insights.addAll(_categoryChanges(allTx, now));
    insights.addAll(_incomeSourceDiversity(allTx, now));
    insights.addAll(_savingsTrend(allTx, now));
    insights.addAll(_categoryVsAverage(allTx, now));
    return insights;
  }

  static bool _inMonth(TransactionModel t, int year, int month) =>
      t.transactionDate.year == year &&
      t.transactionDate.month == month &&
      t.isCompleted;

  static Map<String, double> _expenseByCategory(
      List<TransactionModel> tx, int year, int month) {
    final map = <String, double>{};
    for (final t
        in tx.where((t) => t.type == 'Expense' && _inMonth(t, year, month))) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  /// "You spent 18% less on food this month." / "Transport expenses
  /// increased by 12%." — month-over-month change per category.
  static List<SmartInsight> _categoryChanges(
      List<TransactionModel> tx, DateTime now) {
    final last = DateTime(now.year, now.month - 1);
    final thisMonth = _expenseByCategory(tx, now.year, now.month);
    final lastMonth = _expenseByCategory(tx, last.year, last.month);

    final results = <SmartInsight>[];
    for (final category in thisMonth.keys) {
      final prev = lastMonth[category];
      if (prev == null || prev < 2000)
        continue; // too little history to be meaningful
      final curr = thisMonth[category]!;
      final change = (curr - prev) / prev * 100;
      if (change.abs() < 10) continue;
      final down = change < 0;
      results.add(SmartInsight(
        type: 'category_change_$category',
        title: down ? 'Spending down on $category' : 'Spending up on $category',
        message: down
            ? 'You spent ${change.abs().toStringAsFixed(0)}% less on $category this month.'
            : '$category expenses increased by ${change.abs().toStringAsFixed(0)}% this month.',
        sentiment: down ? 'positive' : 'warning',
      ));
    }
    // Cap so one noisy month doesn't flood the feed — biggest swings first.
    results.sort((a, b) =>
        a.sentiment == b.sentiment ? 0 : (a.sentiment == 'warning' ? -1 : 1));
    return results.take(3).toList();
  }

  /// "You received income from three different sources."
  static List<SmartInsight> _incomeSourceDiversity(
      List<TransactionModel> tx, DateTime now) {
    final sources = tx
        .where((t) => t.type == 'Income' && _inMonth(t, now.year, now.month))
        .map((t) => t.category)
        .toSet();
    if (sources.length < 2) return const [];
    return [
      SmartInsight(
        type: 'income_diversity',
        title: 'Diverse income this month',
        message:
            'You received income from ${sources.length} different sources this month.',
        sentiment: 'positive',
      ),
    ];
  }

  /// "Your savings improved compared to last month."
  static List<SmartInsight> _savingsTrend(
      List<TransactionModel> tx, DateTime now) {
    final last = DateTime(now.year, now.month - 1);
    double savingsOf(int year, int month) {
      final income = tx
          .where((t) =>
              (t.type == 'Income' || t.type == 'Refund') &&
              _inMonth(t, year, month))
          .fold<double>(0, (s, t) => s + t.amount);
      final expense = tx
          .where((t) => t.type == 'Expense' && _inMonth(t, year, month))
          .fold<double>(0, (s, t) => s + t.amount);
      return income - expense;
    }

    final thisSavings = savingsOf(now.year, now.month);
    final lastSavings = savingsOf(last.year, last.month);
    if (lastSavings == 0) return const [];
    final change = (thisSavings - lastSavings) / lastSavings.abs() * 100;
    if (change.abs() < 10) return const [];
    final improved = change > 0;
    return [
      SmartInsight(
        type: 'savings_trend',
        title: improved
            ? 'Congratulations! Savings increased'
            : 'Savings declined',
        message: improved
            ? 'Your savings improved compared to last month (+${formatFCFA(thisSavings - lastSavings)}).'
            : 'Your savings dropped compared to last month (${formatFCFA(thisSavings - lastSavings)}).',
        sentiment: improved ? 'positive' : 'warning',
      ),
    ];
  }

  /// "Entertainment spending exceeded your monthly average."
  static List<SmartInsight> _categoryVsAverage(
      List<TransactionModel> tx, DateTime now) {
    final results = <SmartInsight>[];
    final thisMonth = _expenseByCategory(tx, now.year, now.month);

    for (final category in thisMonth.keys) {
      double total = 0;
      var months = 0;
      for (var i = 1; i <= 3; i++) {
        final m = DateTime(now.year, now.month - i);
        final amt = _expenseByCategory(tx, m.year, m.month)[category];
        if (amt != null) {
          total += amt;
          months++;
        }
      }
      if (months < 2) continue;
      final avg = total / months;
      if (avg < 2000) continue;
      final curr = thisMonth[category]!;
      if (curr > avg * 1.3) {
        results.add(SmartInsight(
          type: 'category_overspend_$category',
          title: '$category above average',
          message: '$category spending exceeded your monthly average '
              '(${formatFCFA(curr)} vs ${formatFCFA(avg)} usual).',
          sentiment: 'warning',
        ));
      }
    }
    return results.take(2).toList();
  }
}
