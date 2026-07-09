import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/fraud_alert_model.dart';
import '../../../models/transaction_model.dart';
import '../../../services/firestore_service.dart';
import '../../accounts/data/account_providers.dart';
import '../../budget/data/budget_providers.dart';
import '../../fraud_detection/data/fraud_detection_providers.dart';
import '../domain/budget_performance.dart';
import '../domain/fraud_review_summary.dart';
import '../domain/fraud_summary.dart';
import '../domain/income_analytics.dart';
import '../domain/report_date_range.dart';
import '../domain/report_summary.dart';

final _reportsFirestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

/// A wider bound than the other modules' analytics streams (500) — Reports
/// explicitly supports a "This year" / custom range view, so it needs more
/// history to stay accurate for active users.
final reportsTransactionsProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, userId) => ref
        .watch(_reportsFirestoreServiceProvider)
        .streamTransactionsLimited(userId, limit: 1000));

/// Selected date-range filter (Today / This week / This month / Last month /
/// This year / Custom).
class ReportDateRangeNotifier extends Notifier<ReportDateRange> {
  @override
  ReportDateRange build() =>
      ReportDateRange.resolve(ReportRangePreset.thisMonth, DateTime.now());

  void setPreset(ReportRangePreset preset) =>
      state = ReportDateRange.resolve(preset, DateTime.now());

  void setCustomRange(DateTime start, DateTime end) =>
      state = ReportDateRange.resolve(ReportRangePreset.custom, DateTime.now(),
          customStart: start, customEnd: end);
}

final reportDateRangeProvider =
    NotifierProvider<ReportDateRangeNotifier, ReportDateRange>(
        ReportDateRangeNotifier.new);

final currentPeriodTransactionsProvider =
    Provider.family<AsyncValue<List<TransactionModel>>, String>((ref, userId) {
  final range = ref.watch(reportDateRangeProvider);
  return ref.watch(reportsTransactionsProvider(userId)).whenData(
      (tx) => tx.where((t) => range.contains(t.transactionDate)).toList());
});

final previousPeriodTransactionsProvider =
    Provider.family<AsyncValue<List<TransactionModel>>, String>((ref, userId) {
  final previous = ref.watch(reportDateRangeProvider).previousPeriod;
  return ref.watch(reportsTransactionsProvider(userId)).whenData(
      (tx) => tx.where((t) => previous.contains(t.transactionDate)).toList());
});

/// Financial Overview Card. Income/expense/savings/balance follow the
/// selected date range; the Financial Health Score deliberately does NOT —
/// it reuses `financialHealthProvider` from Fraud Detection, which is always
/// "this calendar month" (the score's income-consistency factor is
/// inherently monthly-cadence and wouldn't mean anything scoped to, say,
/// "Today").
final reportSummaryProvider =
    Provider.family<AsyncValue<ReportSummary>, String>((ref, userId) {
  final txAsync = ref.watch(currentPeriodTransactionsProvider(userId));
  final accountsAsync = ref.watch(accountsRawProvider(userId));
  final healthAsync = ref.watch(financialHealthProvider(userId));

  if (txAsync.isLoading || accountsAsync.isLoading || healthAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (txAsync.hasError)
    return AsyncValue.error(txAsync.error!, txAsync.stackTrace!);
  if (healthAsync.hasError)
    return AsyncValue.error(healthAsync.error!, healthAsync.stackTrace!);

  final tx = txAsync.value!;
  final income = tx
      .where((t) => t.type == 'Income' && t.isCompleted)
      .fold<double>(0, (s, t) => s + t.amount);
  final expense = tx
      .where((t) => t.type == 'Expense' && t.isCompleted)
      .fold<double>(0, (s, t) => s + t.amount);
  final balance = ref.watch(accountsTotalProvider(userId));

  return AsyncValue.data(ReportSummary(
    totalIncome: income,
    totalExpense: expense,
    currentBalance: balance,
    health: healthAsync.value!,
  ));
});

final incomeAnalyticsProvider =
    Provider.family<AsyncValue<IncomeAnalytics>, String>((ref, userId) {
  final currentAsync = ref.watch(currentPeriodTransactionsProvider(userId));
  final previousAsync = ref.watch(previousPeriodTransactionsProvider(userId));
  if (currentAsync.isLoading || previousAsync.isLoading)
    return const AsyncValue.loading();
  if (currentAsync.hasError) {
    return AsyncValue.error(currentAsync.error!, currentAsync.stackTrace!);
  }
  return AsyncValue.data(IncomeAnalyticsBuilder.build(
    currentPeriodTx: currentAsync.value!,
    previousPeriodTx: previousAsync.valueOrNull ?? const [],
  ));
});

final budgetPerformanceProvider =
    Provider.family<AsyncValue<BudgetPerformance>, String>((ref, userId) {
  return ref
      .watch(allBudgetsWithProgressProvider(userId))
      .whenData((budgets) => BudgetPerformance.build(budgets));
});

final reportFraudAlertsInRangeProvider =
    Provider.family<AsyncValue<List<FraudAlertModel>>, String>((ref, userId) {
  final range = ref.watch(reportDateRangeProvider);
  return ref.watch(fraudAlertsProvider(userId)).whenData(
      (alerts) => alerts.where((a) => range.contains(a.createdAt)).toList());
});

final fraudSummaryProvider =
    Provider.family<AsyncValue<FraudSummary>, String>((ref, userId) {
  final alertsAsync = ref.watch(reportFraudAlertsInRangeProvider(userId));
  final txAsync = ref.watch(currentPeriodTransactionsProvider(userId));
  if (alertsAsync.isLoading || txAsync.isLoading)
    return const AsyncValue.loading();
  if (alertsAsync.hasError)
    return AsyncValue.error(alertsAsync.error!, alertsAsync.stackTrace!);
  if (txAsync.hasError)
    return AsyncValue.error(txAsync.error!, txAsync.stackTrace!);

  return AsyncValue.data(FraudSummary.build(
    alertsInRange: alertsAsync.value!,
    txInRange: txAsync.value!,
  ));
});

final fraudReviewSummaryProvider =
    Provider.family<AsyncValue<FraudReviewSummary>, String>((ref, userId) {
  final txAsync = ref.watch(currentPeriodTransactionsProvider(userId));
  return txAsync.whenData(FraudReviewSummary.build);
});
