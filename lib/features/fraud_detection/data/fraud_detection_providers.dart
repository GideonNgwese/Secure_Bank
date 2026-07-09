import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/financial_insight_model.dart';
import '../../../models/fraud_alert_model.dart';
import '../../../models/notification_model.dart';
import '../../../models/transaction_model.dart';
import '../../../services/firestore_service.dart';
import '../../budget/data/budget_providers.dart';
import '../domain/financial_health.dart';
import 'fraud_detection_repository.dart';

final fraudDetectionRepositoryProvider =
    Provider<FraudDetectionRepository>((ref) => FraudDetectionRepository());

final fraudAlertsProvider =
    StreamProvider.family<List<FraudAlertModel>, String>((ref, userId) =>
        ref.watch(fraudDetectionRepositoryProvider).watchAlerts(userId));

/// The real, durable `notifications` collection — auto-created whenever a
/// fraud alert is generated. This is what the Notifications screen and the
/// header bell badge read for fraud-sourced entries (not `fraud_alerts`
/// directly), so the badge count and the feed can never disagree.
final notificationsProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, userId) =>
        ref.watch(fraudDetectionRepositoryProvider).watchNotifications(userId));

final financialInsightsProvider =
    StreamProvider.family<List<FinancialInsightModel>, String>((ref, userId) =>
        ref.watch(fraudDetectionRepositoryProvider).watchInsights(userId));

final unreadNotificationCountProvider = Provider.family<int, String>(
    (ref, userId) =>
        ref
            .watch(notificationsProvider(userId))
            .valueOrNull
            ?.where((n) => !n.read && !n.dismissed)
            .length ??
        0);

final unreadInsightCountProvider = Provider.family<int, String>((ref, userId) =>
    ref
        .watch(financialInsightsProvider(userId))
        .valueOrNull
        ?.where((i) => i.isUnread)
        .length ??
    0);

/// A bounded, independent transaction stream for fraud/health analytics —
/// deliberately NOT the Transactions feature's paginated list provider,
/// whose page size is a UI concern of that screen and would otherwise leak
/// into these unrelated computations.
final _analyticsFirestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

final analyticsTransactionsProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, userId) => ref
        .watch(_analyticsFirestoreServiceProvider)
        .streamTransactionsLimited(userId, limit: 500));

/// Budget-exceeded notifications from the legacy generic `alerts` collection
/// (still owned by the Budget module) — surfaced read-only inside the
/// unified Alert Center timeline alongside fraud alerts and insights.
final legacyBudgetAlertsProvider = StreamProvider
    .family<List<Map<String, dynamic>>, String>((ref, userId) => ref
        .watch(_analyticsFirestoreServiceProvider)
        .streamAlertsRaw(userId)
        .map((list) => list.where((a) => a['alertType'] == 'budget').toList()));

/// Financial health score, recomputed live from the same signals a personal
/// finance coach would look at. Never persisted — always a fresh snapshot.
/// Budget adherence reuses the Budget module's own [allBudgetsWithProgressProvider]
/// (the canonical source of "budget + its live spend") instead of
/// recomputing usage percentages a second time here.
final financialHealthProvider =
    Provider.family<AsyncValue<FinancialHealthResult>, String>((ref, userId) {
  final txAsync = ref.watch(analyticsTransactionsProvider(userId));
  final budgetsAsync = ref.watch(allBudgetsWithProgressProvider(userId));
  if (txAsync.isLoading || budgetsAsync.isLoading)
    return const AsyncValue.loading();
  if (txAsync.hasError)
    return AsyncValue.error(txAsync.error!, txAsync.stackTrace!);
  if (budgetsAsync.hasError) {
    return AsyncValue.error(budgetsAsync.error!, budgetsAsync.stackTrace!);
  }

  final allTx = txAsync.value!;
  final now = DateTime.now();
  // Only budgets currently in effect count toward "adherence right now".
  final budgets = budgetsAsync.value!
      .where((b) =>
          b.budget.isActive &&
          !now.isBefore(b.budget.startDate) &&
          !now.isAfter(b.budget.endDate))
      .toList();
  final thisMonth = allTx
      .where((t) =>
          t.isCompleted &&
          t.transactionDate.year == now.year &&
          t.transactionDate.month == now.month)
      .toList();

  final income = thisMonth
      .where((t) => t.type == 'Income' || t.type == 'Refund')
      .fold<double>(0, (s, t) => s + t.amount);
  final expense = thisMonth
      .where((t) => t.type == 'Expense')
      .fold<double>(0, (s, t) => s + t.amount);
  final loanExpense = thisMonth
      .where((t) => t.type == 'Expense' && t.category == 'Loan')
      .fold<double>(0, (s, t) => s + t.amount);
  final debtRatio =
      income > 0 ? (loanExpense / income) : (loanExpense > 0 ? 1.0 : 0.0);

  var monthsWithIncome = 0;
  for (var i = 0; i < 3; i++) {
    final m = DateTime(now.year, now.month - i);
    final hasIncome = allTx.any((t) =>
        t.isCompleted &&
        (t.type == 'Income' || t.type == 'Refund') &&
        t.transactionDate.year == m.year &&
        t.transactionDate.month == m.month);
    if (hasIncome) monthsWithIncome++;
  }

  final recentWindow =
      allTx.where((t) => now.difference(t.transactionDate).inDays <= 90);
  final flaggedRatio = recentWindow.isEmpty
      ? 0.0
      : recentWindow.where((t) => t.riskLevel != 'Low').length /
          recentWindow.length;

  final avgBudgetUsagePct = budgets.isEmpty
      ? 0.0
      : budgets.fold<double>(0, (s, b) => s + b.percentUsed) / budgets.length;

  final result = FinancialHealthCalculator.compute(
    income: income,
    expense: expense,
    avgBudgetUsagePct: avgBudgetUsagePct,
    hasBudgets: budgets.isNotEmpty,
    debtRatio: debtRatio,
    monthsWithIncome: monthsWithIncome,
    flaggedRatio: flaggedRatio,
  );
  return AsyncValue.data(result);
});
