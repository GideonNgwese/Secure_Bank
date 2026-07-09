import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/premium_header.dart';
import '../../../../screens/profile/profile_kyc_screen.dart';
import '../../../fraud_detection/data/fraud_detection_providers.dart';
import '../../../fraud_detection/domain/chart_data.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../data/report_providers.dart';
import '../../domain/report_chart_data.dart';
import '../../domain/report_recommendations.dart';
import '../widgets/budget_performance_section.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/expense_analytics_section.dart';
import '../widgets/export_actions_sheet.dart';
import '../widgets/financial_overview_card.dart';
import '../widgets/fraud_review_summary_section.dart';
import '../widgets/fraud_summary_section.dart';
import '../widgets/income_analytics_section.dart';
import '../widgets/recommendations_section.dart';
import '../widgets/report_skeleton.dart';
import '../widgets/spending_trend_chart.dart';

/// The Reports & Financial Analytics dashboard — a professional financial
/// intelligence homepage combining live data from Accounts, Transactions,
/// Budgets and Fraud Detection into one view, with PDF/CSV export.
class ReportsScreen extends ConsumerWidget {
  final String userId;
  final String userName;
  const ReportsScreen(
      {super.key, required this.userId, required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportSummaryProvider(userId));
    final incomeAsync = ref.watch(incomeAnalyticsProvider(userId));
    final budgetsAsync = ref.watch(budgetPerformanceProvider(userId));
    final fraudAsync = ref.watch(fraudSummaryProvider(userId));
    final fraudReviewAsync = ref.watch(fraudReviewSummaryProvider(userId));
    final periodTxAsync = ref.watch(currentPeriodTransactionsProvider(userId));
    final allTxAsync = ref.watch(reportsTransactionsProvider(userId));

    final ready = summaryAsync.hasValue &&
        incomeAsync.hasValue &&
        budgetsAsync.hasValue &&
        fraudAsync.hasValue &&
        fraudReviewAsync.hasValue &&
        periodTxAsync.hasValue &&
        allTxAsync.hasValue;
    // hasValue alone can't distinguish "still loading" from "permanently
    // errored" — both read false. Without this check a failed provider (a
    // bad query, an index still building) looked identical to an infinite
    // loading skeleton, with no way out for the user.
    final hasError = summaryAsync.hasError ||
        incomeAsync.hasError ||
        budgetsAsync.hasError ||
        fraudAsync.hasError ||
        fraudReviewAsync.hasError ||
        periodTxAsync.hasError ||
        allTxAsync.hasError;

    void retry() {
      ref.invalidate(reportSummaryProvider(userId));
      ref.invalidate(incomeAnalyticsProvider(userId));
      ref.invalidate(budgetPerformanceProvider(userId));
      ref.invalidate(fraudSummaryProvider(userId));
      ref.invalidate(fraudReviewSummaryProvider(userId));
      ref.invalidate(currentPeriodTransactionsProvider(userId));
      ref.invalidate(reportsTransactionsProvider(userId));
      ref.invalidate(fraudAlertsProvider(userId));
    }

    return Scaffold(
      body: Column(
        children: [
          PremiumHeader(
            userId: userId,
            title: 'Reports & Analytics',
            onAvatarTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfileKycScreen(userId: userId))),
            onNotificationsTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => NotificationsScreen(userId: userId))),
            onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(userId: userId))),
            stats: summaryAsync.valueOrNull == null
                ? null
                : [
                    HeaderStat(
                        'Financial health',
                        '${summaryAsync.value!.health.score}/100 · '
                            '${summaryAsync.value!.health.label}'),
                  ],
            extraActions: [
              HeaderIconButton(
                icon: Icons.ios_share_outlined,
                isDark: Theme.of(context).brightness == Brightness.dark,
                onTap: ready
                    ? () =>
                        showExportActionsSheet(context, ref, userId, userName)
                    : null,
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(reportsTransactionsProvider(userId));
                ref.invalidate(fraudAlertsProvider(userId));
              },
              child: hasError
                  ? _ReportsErrorState(onRetry: retry)
                  : !ready
                      ? const ReportSkeleton()
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            ResponsiveCenter(
                              maxWidth: 760,
                              scrollable: false,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const FadeSlideIn(child: DateRangeSelector()),
                                  const SizedBox(height: 16),
                                  FadeSlideIn(
                                    duration: const Duration(milliseconds: 450),
                                    child: FinancialOverviewCard(
                                        summary: summaryAsync.value!),
                                  ),
                                  const SizedBox(height: 20),
                                  Text('Income analytics',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 10),
                                  FadeSlideIn(
                                    duration: const Duration(milliseconds: 500),
                                    child: IncomeAnalyticsSection(
                                      income: incomeAsync.value!,
                                      trend: ReportChartData.incomeTrend(
                                          allTxAsync.value!, DateTime.now()),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text('Expense analytics',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 10),
                                  FadeSlideIn(
                                    duration: const Duration(milliseconds: 550),
                                    child: ExpenseAnalyticsSection(
                                      slices: ReportChartData.expenseByCategory(
                                          periodTxAsync.value!),
                                      periodTx: periodTxAsync.value!,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text('Spending trends',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 10),
                                  FadeSlideIn(
                                    duration: const Duration(milliseconds: 600),
                                    child: SpendingTrendChart(
                                      points: ChartDataBuilder.monthlySpending(
                                          allTxAsync.value!, DateTime.now()),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text('Budget performance',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 10),
                                  FadeSlideIn(
                                    duration: const Duration(milliseconds: 650),
                                    child: BudgetPerformanceSection(
                                        performance: budgetsAsync.value!),
                                  ),
                                  const SizedBox(height: 20),
                                  Text('Fraud summary',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 10),
                                  FadeSlideIn(
                                    duration: const Duration(milliseconds: 700),
                                    child: FraudSummarySection(
                                      summary: fraudAsync.value!,
                                      trend: ChartDataBuilder.riskTrend(
                                          ref
                                                  .watch(fraudAlertsProvider(
                                                      userId))
                                                  .valueOrNull ??
                                              const [],
                                          DateTime.now()),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  FadeSlideIn(
                                    duration: const Duration(milliseconds: 720),
                                    child: FraudReviewSummarySection(
                                      summary: fraudReviewAsync.value!,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  FadeSlideIn(
                                    duration: const Duration(milliseconds: 750),
                                    child: RecommendationsSection(
                                      recommendations:
                                          ReportRecommendations.generate(
                                        summary: summaryAsync.value!,
                                        income: incomeAsync.value!,
                                        expenseByCategory:
                                            ReportChartData.expenseByCategory(
                                                periodTxAsync.value!),
                                        budgets: budgetsAsync.value!,
                                        fraud: fraudAsync.value!,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ReportsErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            const Text('Unable to load reports.',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'Check your connection and try again. If this keeps '
                'happening, the data may still be syncing.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
