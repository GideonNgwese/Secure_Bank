import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../models/transaction_model.dart';
import '../../../accounts/data/account_providers.dart';
import '../../../fraud_detection/domain/chart_data.dart' show CategorySlice;
import '../../data/report_providers.dart';
import '../../data/services/report_csv_service.dart';
import '../../data/services/report_pdf_service.dart';
import '../../domain/budget_performance.dart';
import '../../domain/fraud_summary.dart';
import '../../domain/income_analytics.dart';
import '../../domain/report_chart_data.dart';
import '../../domain/report_date_range.dart';
import '../../domain/report_recommendations.dart';
import '../../domain/report_summary.dart';

/// Drives the two export actions. `AsyncData` = idle/succeeded, `AsyncLoading`
/// = generating, `AsyncError` = failed (UI shows the friendly message).
class ReportExportController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Snapshots every provider the report needs. Throws a friendly message if
  /// any of them hasn't finished loading yet — exporting mid-load would
  /// silently produce an incomplete report otherwise.
  ({
    ReportDateRange range,
    ReportSummary summary,
    IncomeAnalytics income,
    List<CategorySlice> expenses,
    BudgetPerformance budgets,
    FraudSummary fraud,
    List<TransactionModel> periodTx,
    Map<String, String> accountNames,
  }) _snapshot(String userId) {
    final range = ref.read(reportDateRangeProvider);
    final summary = ref.read(reportSummaryProvider(userId)).valueOrNull;
    final income = ref.read(incomeAnalyticsProvider(userId)).valueOrNull;
    final budgets = ref.read(budgetPerformanceProvider(userId)).valueOrNull;
    final fraud = ref.read(fraudSummaryProvider(userId)).valueOrNull;
    final periodTx =
        ref.read(currentPeriodTransactionsProvider(userId)).valueOrNull;
    final accounts = ref.read(accountsRawProvider(userId)).valueOrNull ?? [];

    if (summary == null ||
        income == null ||
        budgets == null ||
        fraud == null ||
        periodTx == null) {
      throw const ServerException(
          'Your report is still loading — try again in a moment.');
    }

    return (
      range: range,
      summary: summary,
      income: income,
      expenses: ReportChartData.expenseByCategory(periodTx),
      budgets: budgets,
      fraud: fraud,
      periodTx: periodTx,
      accountNames: {for (final a in accounts) a.id: a.accountName},
    );
  }

  Future<bool> exportPdf(
      {required String userId, required String userName}) async {
    state = const AsyncLoading();
    try {
      final s = _snapshot(userId);
      final recommendations = ReportRecommendations.generate(
        summary: s.summary,
        income: s.income,
        expenseByCategory: s.expenses,
        budgets: s.budgets,
        fraud: s.fraud,
      );
      final bytes = await ReportPdfService().build(
        userName: userName,
        range: s.range,
        summary: s.summary,
        income: s.income,
        expenseByCategory: s.expenses,
        budgets: s.budgets,
        fraud: s.fraud,
        recommendations: recommendations,
      );
      await Printing.sharePdf(
          bytes: bytes,
          filename:
              'securebank_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
      return false;
    }
  }

  Future<bool> exportCsv(String userId) async {
    state = const AsyncLoading();
    try {
      final s = _snapshot(userId);
      final csv = ReportCsvService().build(
        range: s.range,
        summary: s.summary,
        income: s.income,
        expenseByCategory: s.expenses,
        budgets: s.budgets,
        fraud: s.fraud,
        periodTx: s.periodTx,
        accountNames: s.accountNames,
      );
      await Clipboard.setData(ClipboardData(text: csv));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
      return false;
    }
  }
}

final reportExportControllerProvider =
    AutoDisposeAsyncNotifierProvider<ReportExportController, void>(
        ReportExportController.new);
