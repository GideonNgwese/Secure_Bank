import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/budget_model.dart';
import '../../../models/transaction_model.dart';
import '../../../services/firestore_service.dart';
import '../domain/budget_health.dart';
import '../domain/budget_query.dart';
import '../domain/budget_summary.dart';
import '../domain/budget_view.dart';
import 'budget_repository.dart';

final budgetRepositoryProvider =
    Provider<BudgetRepository>((ref) => BudgetRepository());

final _budgetFirestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final budgetsRawProvider = StreamProvider.family<List<BudgetModel>, String>(
    (ref, userId) => ref.watch(budgetRepositoryProvider).watchAll(userId));

/// Bounded, independent transaction stream for budget spend computation —
/// deliberately not shared with the Transactions screen's paginated
/// provider (different page-size lifecycle) or the Fraud module's
/// (different feature, avoids a cross-feature coupling both ways since
/// fraud_detection already depends on `BudgetModel`).
final budgetAnalyticsTransactionsProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, userId) => ref
        .watch(_budgetFirestoreServiceProvider)
        .streamTransactionsLimited(userId, limit: 500));

/// Every budget paired with its live-computed spend, unfiltered — the
/// source both the dashboard summary and the (separately filtered) visible
/// list are derived from.
final allBudgetsWithProgressProvider =
    Provider.family<AsyncValue<List<BudgetWithProgress>>, String>(
        (ref, userId) {
  final budgetsAsync = ref.watch(budgetsRawProvider(userId));
  final txAsync = ref.watch(budgetAnalyticsTransactionsProvider(userId));

  return budgetsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (budgets) => txAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
      data: (tx) => AsyncValue.data([
        for (final b in budgets) BudgetWithProgress(b, b.spentFrom(tx)),
      ]),
    ),
  );
});

/// Search / filter / sort state.
class BudgetQueryNotifier extends Notifier<BudgetQuery> {
  @override
  BudgetQuery build() => const BudgetQuery();

  void setSearch(String s) => state = state.copyWith(search: s);
  void setPeriod(String? p) => state = state.copyWith(period: () => p);
  void setCategory(String? c) => state = state.copyWith(category: () => c);
  void setStatus(String? s) => state = state.copyWith(status: () => s);
  void setSort(BudgetSort s) => state = state.copyWith(sort: s);
  void clearFilters() => state = state.clearFilters();
}

final budgetQueryProvider =
    NotifierProvider<BudgetQueryNotifier, BudgetQuery>(BudgetQueryNotifier.new);

/// The list after search, filters and sort are applied.
final visibleBudgetsProvider =
    Provider.family<AsyncValue<List<BudgetWithProgress>>, String>(
        (ref, userId) {
  final allAsync = ref.watch(allBudgetsWithProgressProvider(userId));
  final query = ref.watch(budgetQueryProvider);

  return allAsync.whenData((all) {
    var list = all;
    final q = query.search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((b) =>
              b.budget.name.toLowerCase().contains(q) ||
              b.budget.category.toLowerCase().contains(q) ||
              b.budget.period.toLowerCase().contains(q))
          .toList();
    }
    if (query.period != null) {
      list = list.where((b) => b.budget.period == query.period).toList();
    }
    if (query.category != null) {
      list = list.where((b) => b.budget.category == query.category).toList();
    }
    if (query.status != null) {
      list = list.where((b) => b.displayStatus == query.status).toList();
    }
    switch (query.sort) {
      case BudgetSort.newest:
        list = [...list]
          ..sort((a, b) => b.budget.createdAt.compareTo(a.budget.createdAt));
      case BudgetSort.nameAz:
        list = [...list]..sort((a, b) =>
            a.budget.name.toLowerCase().compareTo(b.budget.name.toLowerCase()));
      case BudgetSort.highestAmount:
        list = [...list]..sort(
            (a, b) => b.budget.budgetAmount.compareTo(a.budget.budgetAmount));
      case BudgetSort.lowestAmount:
        list = [...list]..sort(
            (a, b) => a.budget.budgetAmount.compareTo(b.budget.budgetAmount));
      case BudgetSort.mostUsed:
        list = [...list]
          ..sort((a, b) => b.percentUsed.compareTo(a.percentUsed));
    }
    return list;
  });
});

/// Distinct categories among the user's own budgets, for the category filter.
final budgetCategoryOptionsProvider =
    Provider.family<List<String>, String>((ref, userId) {
  final budgets = ref.watch(budgetsRawProvider(userId)).valueOrNull ?? [];
  final set = budgets.map((b) => b.category).toSet().toList()..sort();
  return set;
});

/// Aggregate figures for the "Home Budget Dashboard" header.
final budgetSummaryProvider =
    Provider.family<AsyncValue<BudgetSummary>, String>((ref, userId) {
  final allAsync = ref.watch(allBudgetsWithProgressProvider(userId));
  final txAsync = ref.watch(budgetAnalyticsTransactionsProvider(userId));

  return allAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (all) {
      final now = DateTime.now();
      final active = all.where((b) => b.budget.isActive && !b.isEnded).toList();

      final totalBudget =
          active.fold<double>(0, (s, b) => s + b.budget.budgetAmount);
      final totalSpent = active.fold<double>(0, (s, b) => s + b.spentAmount);
      final overspending =
          active.where((b) => b.tier == BudgetRiskTier.exceeded).length;
      final endingSoon = active.where((b) => b.daysRemaining <= 3).length;

      final tx = txAsync.valueOrNull ?? [];
      final monthIncome = tx
          .where((t) =>
              t.isCompleted &&
              (t.type == 'Income' || t.type == 'Refund') &&
              t.transactionDate.year == now.year &&
              t.transactionDate.month == now.month)
          .fold<double>(0, (s, t) => s + t.amount);
      final monthExpense = tx
          .where((t) =>
              t.isCompleted &&
              t.type == 'Expense' &&
              t.transactionDate.year == now.year &&
              t.transactionDate.month == now.month)
          .fold<double>(0, (s, t) => s + t.amount);

      return AsyncValue.data(BudgetSummary(
        totalBudget: totalBudget,
        totalSpent: totalSpent,
        totalRemaining: totalBudget - totalSpent,
        savingsThisMonth: monthIncome - monthExpense,
        health: BudgetHealthCalculator.compute(active),
        overspendingCount: overspending,
        endingSoonCount: endingSoon,
      ));
    },
  );
});
