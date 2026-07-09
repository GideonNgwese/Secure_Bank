import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/providers/header_provider.dart';
import '../../../../core/widgets/premium_header.dart';
import '../../../../models/financial_insight_model.dart';
import '../../../../models/fraud_alert_model.dart';
import '../../../../screens/profile/profile_kyc_screen.dart';
import '../../../../services/firestore_service.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../transactions/presentation/screens/transaction_detail_screen.dart';
import '../../data/fraud_detection_providers.dart';
import '../../domain/chart_data.dart';
import '../../domain/risk_level.dart';
import '../controllers/fraud_center_controller.dart';
import '../widgets/budget_alert_tile.dart';
import '../widgets/fraud_empty_state.dart';
import '../widgets/health_score_gauge.dart';
import '../widgets/insight_card.dart';
import '../widgets/insight_charts.dart';
import '../widgets/risk_alert_card.dart';

enum _TimelineFilter { all, alerts, insights, budget }

/// One item in the merged, chronologically-sorted timeline — tags which
/// source it came from so the builder knows which card widget to render.
class _TimelineItem {
  final DateTime createdAt;
  final _TimelineFilter kind;
  final FraudAlertModel? alert;
  final FinancialInsightModel? insight;
  final Map<String, dynamic>? budget;

  _TimelineItem.alert(this.alert)
      : createdAt = alert!.createdAt,
        kind = _TimelineFilter.alerts,
        insight = null,
        budget = null;
  _TimelineItem.insight(this.insight)
      : createdAt = insight!.createdAt,
        kind = _TimelineFilter.insights,
        alert = null,
        budget = null;
  _TimelineItem.budget(this.budget)
      : createdAt =
            DateTime.tryParse(budget!['createdAt'] ?? '') ?? DateTime.now(),
        kind = _TimelineFilter.budget,
        alert = null,
        insight = null;
}

/// The Fraud & Financial Intelligence Center — this app's "Alert Center".
/// Shows a live financial health score, five analytics charts, and a
/// unified, filterable timeline of fraud alerts, smart insights, and budget
/// notifications. This is NOT real bank fraud detection — it's a personal
/// finance awareness tool that flags patterns worth a second look.
class FraudCenterScreen extends ConsumerStatefulWidget {
  final String userId;
  const FraudCenterScreen({super.key, required this.userId});

  @override
  ConsumerState<FraudCenterScreen> createState() => _FraudCenterScreenState();
}

class _FraudCenterScreenState extends ConsumerState<FraudCenterScreen> {
  _TimelineFilter _filter = _TimelineFilter.all;
  bool _generatedThisSession = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateInsights());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _generateInsights() async {
    if (_generatedThisSession) return;
    _generatedThisSession = true;
    try {
      final tx =
          await ref.read(analyticsTransactionsProvider(widget.userId).future);
      if (!mounted) return;
      await ref
          .read(fraudCenterControllerProvider.notifier)
          .generateInsights(widget.userId, tx);
    } catch (_) {
      // Insights are a nice-to-have — never block the screen on this failing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(financialHealthProvider(widget.userId));
    final txAsync = ref.watch(analyticsTransactionsProvider(widget.userId));
    final alertsAsync = ref.watch(fraudAlertsProvider(widget.userId));
    final insightsAsync = ref.watch(financialInsightsProvider(widget.userId));
    final budgetAsync = ref.watch(legacyBudgetAlertsProvider(widget.userId));
    final securityScore = ref.watch(headerSecurityScoreProvider(widget.userId));

    return Scaffold(
      body: Column(
        children: [
          PremiumHeader(
            userId: widget.userId,
            title: 'Fraud & Insights',
            scrollController: _scrollController,
            onAvatarTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfileKycScreen(userId: widget.userId))),
            onNotificationsTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        NotificationsScreen(userId: widget.userId))),
            onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(userId: widget.userId))),
            stats: [
              HeaderStat('Security score', '$securityScore/100',
                  valueColor: securityScore >= 80
                      ? AppTokens.success
                      : securityScore >= 50
                          ? AppTokens.warning
                          : AppTokens.danger),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(analyticsTransactionsProvider(widget.userId));
                ref.invalidate(fraudAlertsProvider(widget.userId));
                ref.invalidate(financialInsightsProvider(widget.userId));
                _generatedThisSession = false;
                await _generateInsights();
              },
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  ResponsiveCenter(
                    maxWidth: 720,
                    scrollable: false,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeSlideIn(
                          child: healthAsync.when(
                            loading: () => const _CardSkeleton(height: 260),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (result) => HealthScoreGauge(result: result),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('Analytics',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        txAsync.when(
                          loading: () => const Column(children: [
                            _CardSkeleton(height: 220),
                            SizedBox(height: 12),
                            _CardSkeleton(height: 220),
                          ]),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (tx) {
                            final now = DateTime.now();
                            return Column(
                              children: [
                                FadeSlideIn(
                                  duration: const Duration(milliseconds: 450),
                                  child: MonthlySpendingChart(
                                      points: ChartDataBuilder.monthlySpending(
                                          tx, now)),
                                ),
                                const SizedBox(height: 12),
                                FadeSlideIn(
                                  duration: const Duration(milliseconds: 500),
                                  child: IncomeVsExpenseChart(
                                      points: ChartDataBuilder.incomeVsExpense(
                                          tx, now)),
                                ),
                                const SizedBox(height: 12),
                                FadeSlideIn(
                                  duration: const Duration(milliseconds: 550),
                                  child: CategoryBreakdownChart(
                                      slices:
                                          ChartDataBuilder.categoryBreakdown(
                                              tx, now)),
                                ),
                                const SizedBox(height: 12),
                                FadeSlideIn(
                                  duration: const Duration(milliseconds: 600),
                                  child: SavingsGrowthChart(
                                      points: ChartDataBuilder.savingsGrowth(
                                          tx, now)),
                                ),
                                const SizedBox(height: 12),
                                FadeSlideIn(
                                  duration: const Duration(milliseconds: 650),
                                  child: alertsAsync.maybeWhen(
                                    data: (alerts) => RiskTrendChart(
                                        points: ChartDataBuilder.riskTrend(
                                            alerts, now)),
                                    orElse: () =>
                                        const _CardSkeleton(height: 170),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        Text('Timeline',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        _filterChips(),
                        const SizedBox(height: 12),
                        _timeline(alertsAsync, insightsAsync, budgetAsync),
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

  Widget _filterChips() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip('All', _TimelineFilter.all),
          _chip('Alerts', _TimelineFilter.alerts),
          _chip('Insights', _TimelineFilter.insights),
          _chip('Budget', _TimelineFilter.budget),
        ],
      ),
    );
  }

  Widget _chip(String label, _TimelineFilter value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: AppTokens.brand.withValues(alpha: 0.16),
        labelStyle: TextStyle(
            color: selected ? AppTokens.brand : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
      ),
    );
  }

  Widget _timeline(
    AsyncValue<List<FraudAlertModel>> alertsAsync,
    AsyncValue<List<FinancialInsightModel>> insightsAsync,
    AsyncValue<List<Map<String, dynamic>>> budgetAsync,
  ) {
    if (alertsAsync.isLoading ||
        insightsAsync.isLoading ||
        budgetAsync.isLoading) {
      return const Column(children: [
        _CardSkeleton(height: 90),
        SizedBox(height: 10),
        _CardSkeleton(height: 90),
      ]);
    }

    final items = <_TimelineItem>[
      if (_filter == _TimelineFilter.all || _filter == _TimelineFilter.alerts)
        ...(alertsAsync.valueOrNull ?? []).map(_TimelineItem.alert),
      if (_filter == _TimelineFilter.all || _filter == _TimelineFilter.insights)
        ...(insightsAsync.valueOrNull ?? []).map(_TimelineItem.insight),
      if (_filter == _TimelineFilter.all || _filter == _TimelineFilter.budget)
        ...(budgetAsync.valueOrNull ?? []).map(_TimelineItem.budget),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (items.isEmpty) return const FraudEmptyState();

    final controller = ref.read(fraudCenterControllerProvider.notifier);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeSlideIn(
              duration: Duration(milliseconds: 300 + (i.clamp(0, 6) * 40)),
              offsetY: 10,
              child: _buildItem(items[i], controller),
            ),
          ),
      ],
    );
  }

  Widget _buildItem(_TimelineItem item, FraudCenterController controller) {
    switch (item.kind) {
      case _TimelineFilter.alerts:
        final a = item.alert!;
        return RiskAlertCard(
          alert: a,
          onTap: () => _showAlertDetails(a, controller),
          onMarkRead: a.isUnread ? () => controller.markAlertRead(a.id) : null,
          onDismiss: a.status == 'dismissed'
              ? null
              : () => controller.dismissAlert(a.id),
        );
      case _TimelineFilter.insights:
        final ins = item.insight!;
        return InsightCard(
          insight: ins,
          onMarkRead:
              ins.isUnread ? () => controller.markInsightRead(ins.id) : null,
          onDismiss: ins.status == 'dismissed'
              ? null
              : () => controller.dismissInsight(ins.id),
        );
      case _TimelineFilter.budget:
        final b = item.budget!;
        return BudgetAlertTile(
          alert: b,
          onMarkRead: b['status'] == 'unread'
              ? () => FirestoreService().markAlertRead(b['id'] as String)
              : null,
        );
      case _TimelineFilter.all:
        return const SizedBox.shrink();
    }
  }

  /// "View details" — the full alert plus a jump straight to the
  /// transaction that triggered it, so the user can see exactly what was
  /// flagged rather than just the summarized card text.
  void _showAlertDetails(FraudAlertModel a, FraudCenterController controller) {
    final level = RiskLevelX.fromName(a.riskLevel);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'fraud-alert-${a.id}',
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: level.color.withValues(alpha: 0.14),
                          shape: BoxShape.circle),
                      child: Icon(level.icon, color: level.color, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${level.label} risk',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: level.color)),
                        Text(
                            'Score ${a.riskScore} of 100 • ${DateFormat.yMMMd().add_jm().format(a.createdAt)}',
                            style: const TextStyle(fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('What we noticed',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(a.reason, style: const TextStyle(fontSize: 14, height: 1.4)),
              const SizedBox(height: 16),
              Text('Recommendation',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(a.recommendation,
                  style: const TextStyle(fontSize: 14, height: 1.4)),
              const SizedBox(height: 22),
              if (a.transactionId.isNotEmpty)
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => TransactionDetailScreen(
                              userId: widget.userId,
                              transactionId: a.transactionId)));
                    },
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTokens.brand),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: const Text('View transaction'),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (a.isUnread)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          controller.markAlertRead(a.id);
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Mark read'),
                      ),
                    ),
                  if (a.isUnread && a.status != 'dismissed')
                    const SizedBox(width: 10),
                  if (a.status != 'dismissed')
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          controller.dismissAlert(a.id);
                          Navigator.of(sheetContext).pop();
                        },
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppTokens.danger),
                        child: const Text('Dismiss'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  final double height;
  const _CardSkeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
    );
  }
}
