import 'package:flutter/material.dart';
import '../../../models/account_model.dart';
import '../../../models/transaction_model.dart';
import '../../../utils/constants.dart';

/// An account paired with its computed current balance.
class AccountBalance {
  final AccountModel account;
  final double balance;
  const AccountBalance(this.account, this.balance);
}

/// A small AI-style financial insight card.
class Insight {
  final IconData icon;
  final String text;
  final Color color;
  const Insight(this.icon, this.text, this.color);
}

/// One month's income/expense point for the trend chart.
class TrendPoint {
  final String label;
  final double income;
  final double expense;
  const TrendPoint(this.label, this.income, this.expense);
}

/// Everything the dashboard needs, computed once from the raw streams so the
/// UI never does business logic.
class DashboardData {
  final List<AccountBalance> accounts;
  final double totalBalance;
  final double income; // current month
  final double expense; // current month
  final List<TransactionModel> recent; // latest few
  final List<TransactionModel> flagged; // risk != Low
  final Map<String, double> spendingByCategory; // current month expenses
  final List<TrendPoint> trend; // last 6 months
  final List<Insight> insights;
  // Fraud Review Workflow live counts (all-time, not just this month) — the
  // Dashboard's "Fraud Reviews" summary card.
  final int pendingReviewCount;
  final int approvedReviewCount;
  final int declinedReviewCount;

  const DashboardData({
    required this.accounts,
    required this.totalBalance,
    required this.income,
    required this.expense,
    required this.recent,
    required this.flagged,
    required this.spendingByCategory,
    required this.trend,
    required this.insights,
    this.pendingReviewCount = 0,
    this.approvedReviewCount = 0,
    this.declinedReviewCount = 0,
  });

  // Negative is a real monthly deficit, not "no savings" — flooring at 0
  // would quietly hide a shortfall the user needs to see.
  double get savings => income - expense;
  int get flaggedCount => flagged.length;
  bool get isEmpty => accounts.isEmpty && recent.isEmpty;
  // Reuses [flagged] (already risk-filtered) rather than a second pass over
  // all transactions — every Pending Review transaction is necessarily
  // Medium+ risk, so it's already in that list.
  List<TransactionModel> get pendingReviewTransactions =>
      flagged.where((t) => t.isPendingReview).toList();

  factory DashboardData.compute(
      List<AccountModel> accounts, List<TransactionModel> txs) {
    final now = DateTime.now();

    final accBal = accounts
        .map((a) => AccountBalance(a, a.computeBalance(txs)))
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
    final total = accBal
        .where((a) => a.account.status == 'Active')
        .fold<double>(0, (s, a) => s + a.balance);

    bool inMonth(TransactionModel t, DateTime m) =>
        t.transactionDate.month == m.month && t.transactionDate.year == m.year;

    // Transfers/Adjustments are balance movements, not real earning/spending,
    // so they're excluded here the same way Transfer always was — only
    // Income/Refund count as money in, Expense as money out.
    final monthTx = txs.where((t) => inMonth(t, now) && t.isCompleted).toList();
    final income = monthTx
        .where((t) => t.type == 'Income' || t.type == 'Refund')
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = monthTx
        .where((t) => t.type == 'Expense')
        .fold<double>(0, (s, t) => s + t.amount);

    final byCat = <String, double>{};
    for (final t in monthTx.where((t) => t.type == 'Expense')) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }

    final sorted = [...txs]
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    final recent = sorted.take(6).toList();
    final flagged = sorted.where((t) => t.riskLevel != 'Low').toList();

    const months = [
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
    final trend = <TrendPoint>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      final mt = txs.where((t) => inMonth(t, m) && t.isCompleted);
      trend.add(TrendPoint(
        months[m.month - 1],
        mt
            .where((t) => t.type == 'Income' || t.type == 'Refund')
            .fold<double>(0, (s, t) => s + t.amount),
        mt
            .where((t) => t.type == 'Expense')
            .fold<double>(0, (s, t) => s + t.amount),
      ));
    }

    return DashboardData(
      accounts: accBal,
      totalBalance: total,
      income: income,
      expense: expense,
      recent: recent,
      flagged: flagged,
      spendingByCategory: byCat,
      trend: trend,
      insights: _insights(txs, now, income, expense, byCat),
      pendingReviewCount:
          txs.where((t) => t.status == 'Pending Review').length,
      approvedReviewCount: txs.where((t) => t.status == 'Approved').length,
      declinedReviewCount: txs.where((t) => t.status == 'Declined').length,
    );
  }

  static List<Insight> _insights(List<TransactionModel> txs, DateTime now,
      double income, double expense, Map<String, double> byCat) {
    final list = <Insight>[];

    final last = DateTime(now.year, now.month - 1);
    final lastExpense = txs
        .where((t) =>
            t.type == 'Expense' &&
            t.isCompleted &&
            t.transactionDate.month == last.month &&
            t.transactionDate.year == last.year)
        .fold<double>(0, (s, t) => s + t.amount);
    if (lastExpense > 0) {
      final diff = (expense - lastExpense) / lastExpense * 100;
      if (diff.abs() >= 5) {
        list.add(Insight(
          diff < 0 ? Icons.trending_down : Icons.trending_up,
          'You spent ${diff.abs().toStringAsFixed(0)}% ${diff < 0 ? 'less' : 'more'} than last month.',
          diff < 0 ? AppColors.success : AppColors.warning,
        ));
      }
    }

    if (income > expense && income > 0) {
      list.add(Insight(
          Icons.savings_outlined,
          'You saved ${formatFCFA(income - expense)} this month.',
          AppColors.success));
    }

    if (byCat.isNotEmpty) {
      final top = byCat.entries.reduce((a, b) => a.value > b.value ? a : b);
      list.add(Insight(
          Icons.donut_small_outlined,
          'Most spending on ${top.key} (${formatFCFA(top.value)}).',
          AppColors.primary));
    }

    final flaggedThisMonth = txs
        .where((t) =>
            t.riskLevel != 'Low' &&
            t.transactionDate.month == now.month &&
            t.transactionDate.year == now.year)
        .length;
    if (flaggedThisMonth > 0) {
      list.add(Insight(Icons.gpp_maybe_outlined,
          'Unusual activity detected — review your alerts.', AppColors.danger));
    }

    if (list.isEmpty) {
      list.add(const Insight(
          Icons.insights_outlined,
          'Add transactions to unlock personalised insights.',
          AppColors.primary));
    }
    return list.take(3).toList();
  }
}
