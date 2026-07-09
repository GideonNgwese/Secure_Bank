import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/premium_header.dart';
import '../../../../models/budget_model.dart';
import '../../../../models/transaction_model.dart';
import '../../../../screens/profile/profile_kyc_screen.dart';
import '../../../../utils/constants.dart';
import '../../../fraud_detection/domain/chart_data.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../data/budget_providers.dart';
import '../../domain/budget_chart_data.dart';
import '../../domain/budget_insights.dart';
import '../../domain/budget_view.dart';
import '../controllers/budget_alerts_controller.dart';
import '../controllers/budget_form_controller.dart';
import '../widgets/budget_card.dart';
import '../widgets/budget_charts.dart';
import '../widgets/budget_empty_state.dart';
import '../widgets/budget_insight_card.dart';
import '../widgets/budget_search_filter_bar.dart';
import '../widgets/budget_summary_header.dart';
import 'budget_detail_screen.dart';
import 'budget_form_screen.dart';

/// Premium Budget Management home: the "Home Budget Dashboard" summary,
/// smart insights, analytics charts, search/filter, and a swipeable,
/// animated list of budget cards. Entry point for the bottom-nav "Budget" tab.
class BudgetListScreen extends ConsumerStatefulWidget {
  final String userId;
  const BudgetListScreen({super.key, required this.userId});

  @override
  ConsumerState<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends ConsumerState<BudgetListScreen> {
  bool _checkedAlertsThisSession = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAlerts());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkAlerts() async {
    if (_checkedAlertsThisSession) return;
    _checkedAlertsThisSession = true;
    await ref
        .read(budgetAlertsControllerProvider.notifier)
        .checkTimeBasedAlerts(widget.userId);
  }

  void _openCreate() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BudgetFormScreen(userId: widget.userId)));

  void _openEdit(BudgetModel b) => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BudgetFormScreen(userId: widget.userId, existing: b)));

  void _openDetail(BudgetModel b) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              BudgetDetailScreen(userId: widget.userId, budgetId: b.id)));

  @override
  Widget build(BuildContext context) {
    final rawAsync = ref.watch(budgetsRawProvider(widget.userId));
    final rawLoaded = rawAsync.valueOrNull;
    final trulyEmpty = rawLoaded != null && rawLoaded.isEmpty;
    final visibleAsync = ref.watch(visibleBudgetsProvider(widget.userId));
    final allAsync = ref.watch(allBudgetsWithProgressProvider(widget.userId));
    final summaryAsync = ref.watch(budgetSummaryProvider(widget.userId));
    final txAsync =
        ref.watch(budgetAnalyticsTransactionsProvider(widget.userId));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        backgroundColor: AppTokens.brand,
        icon: const Icon(Icons.add),
        label: const Text('Add budget'),
      ),
      body: Column(
        children: [
          PremiumHeader(
            userId: widget.userId,
            title: 'Budgets',
            scrollController: _scrollController,
            onAvatarTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfileKycScreen(userId: widget.userId))),
            onNotificationsTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        NotificationsScreen(userId: widget.userId))),
            onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(userId: widget.userId))),
            stats: summaryAsync.valueOrNull == null
                ? null
                : [
                    HeaderStat('Remaining',
                        formatFCFA(summaryAsync.valueOrNull!.totalRemaining)),
                  ],
          ),
          Expanded(
            child: trulyEmpty
                ? BudgetEmptyState(onCreate: _openCreate)
                : RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(budgetsRawProvider(widget.userId));
                      ref.invalidate(
                          budgetAnalyticsTransactionsProvider(widget.userId));
                      _checkedAlertsThisSession = false;
                      await _checkAlerts();
                    },
                    child: rawLoaded == null
                        ? const Center(child: CircularProgressIndicator())
                        : CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              SliverToBoxAdapter(
                                child: ResponsiveCenter(
                                  maxWidth: 720,
                                  scrollable: false,
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      FadeSlideIn(
                                        child: summaryAsync.when(
                                          loading: () =>
                                              const _Skeleton(height: 260),
                                          error: (_, __) =>
                                              const SizedBox.shrink(),
                                          data: (summary) =>
                                              BudgetSummaryHeader(
                                                  summary: summary),
                                        ),
                                      ),
                                      allAsync.maybeWhen(
                                        data: (all) => _insightsSection(all,
                                            txAsync.valueOrNull ?? const []),
                                        orElse: () => const SizedBox.shrink(),
                                      ),
                                      const SizedBox(height: 22),
                                      Text('Analytics',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 10),
                                      allAsync.maybeWhen(
                                        data: (all) => _analyticsSection(all,
                                            txAsync.valueOrNull ?? const []),
                                        orElse: () => const Column(children: [
                                          _Skeleton(height: 200),
                                          SizedBox(height: 12),
                                          _Skeleton(height: 200),
                                        ]),
                                      ),
                                      const SizedBox(height: 22),
                                      Text('My budgets',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 10),
                                      BudgetSearchFilterBar(
                                          userId: widget.userId),
                                    ],
                                  ),
                                ),
                              ),
                              visibleAsync.when(
                                loading: () => const SliverFillRemaining(
                                    child: Center(
                                        child: CircularProgressIndicator())),
                                error: (e, _) => SliverFillRemaining(
                                  child: _ErrorState(
                                      onRetry: () => ref.invalidate(
                                          budgetsRawProvider(widget.userId))),
                                ),
                                data: (items) => items.isEmpty
                                    ? const SliverFillRemaining(
                                        hasScrollBody: false,
                                        child: _NoMatchesState())
                                    : SliverPadding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 8, 16, 100),
                                        sliver: context.isTablet
                                            ? _grid(items)
                                            : _list(items),
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

  Widget _insightsSection(
      List<BudgetWithProgress> all, List<TransactionModel> tx) {
    final active = all.where((b) => b.budget.isActive && !b.isEnded).toList();
    final insights = BudgetInsightsEngine.generate(
        activeBudgets: active, allTx: tx, now: DateTime.now());
    if (insights.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Text('Smart insights', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (var i = 0; i < insights.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FadeSlideIn(
              duration: Duration(milliseconds: 350 + i * 60),
              offsetY: 10,
              child: BudgetInsightCard(insight: insights[i]),
            ),
          ),
      ],
    );
  }

  Widget _analyticsSection(
      List<BudgetWithProgress> all, List<TransactionModel> tx) {
    final active = all.where((b) => b.budget.isActive).toList();
    final now = DateTime.now();
    return Column(
      children: [
        FadeSlideIn(
          duration: const Duration(milliseconds: 450),
          child: BudgetCategorySpendingChart(
              slices: BudgetChartDataBuilder.categorySpending(active)),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          duration: const Duration(milliseconds: 500),
          child: BudgetVsActualChart(
              points: BudgetChartDataBuilder.budgetVsActual(active)),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          duration: const Duration(milliseconds: 550),
          child: BudgetMonthlyTrendsChart(
              points: ChartDataBuilder.monthlySpending(tx, now)),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          duration: const Duration(milliseconds: 600),
          child: BudgetSavingsGrowthChart(
              points: ChartDataBuilder.savingsGrowth(tx, now)),
        ),
        const SizedBox(height: 12),
        FadeSlideIn(
          duration: const Duration(milliseconds: 650),
          child: BudgetRemainingChart(
              slices: BudgetChartDataBuilder.remainingBudget(active)),
        ),
      ],
    );
  }

  Widget _list(List<BudgetWithProgress> items) {
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => FadeSlideIn(
        duration: Duration(milliseconds: 320 + (i.clamp(0, 8) * 40)),
        child: _SwipeableBudgetTile(
          item: items[i],
          onTap: () => _openDetail(items[i].budget),
          onEdit: () => _openEdit(items[i].budget),
        ),
      ),
    );
  }

  Widget _grid(List<BudgetWithProgress> items) {
    final cols = context.isDesktop ? 3 : 2;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) => FadeSlideIn(
          duration: Duration(milliseconds: 320 + (i.clamp(0, 8) * 40)),
          child: BudgetCard(
            item: items[i],
            onTap: () => _openDetail(items[i].budget),
            onLongPress: () => showBudgetActionsSheet(context, ref,
                items[i].budget, () => _openEdit(items[i].budget)),
          ),
        ),
        childCount: items.length,
      ),
    );
  }
}

/// Swipe right → edit (snaps back), swipe left → delete (with confirmation).
/// Long press → the full quick-actions sheet (duplicate/archive/reset/delete).
class _SwipeableBudgetTile extends ConsumerWidget {
  final BudgetWithProgress item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const _SwipeableBudgetTile(
      {required this.item, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = item.budget;
    return Dismissible(
      key: ValueKey('budget-swipe-${b.id}'),
      direction: DismissDirection.horizontal,
      background: _background(
          alignment: Alignment.centerLeft,
          color: AppTokens.brand,
          icon: Icons.edit_outlined,
          label: 'Edit'),
      secondaryBackground: _background(
          alignment: Alignment.centerRight,
          color: AppColors.critical,
          icon: Icons.delete_outline,
          label: 'Delete'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false;
        }
        return _confirmDelete(context, ref, b);
      },
      onDismissed: (_) =>
          ref.read(budgetFormControllerProvider.notifier).delete(b.id),
      child: BudgetCard(
        item: item,
        onTap: onTap,
        onLongPress: () => showBudgetActionsSheet(context, ref, b, onEdit),
      ),
    );
  }

  Widget _background(
      {required Alignment alignment,
      required Color color,
      required IconData icon,
      required String label}) {
    final leading = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: leading
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ]
            : [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }
}

Future<bool> _confirmDelete(
    BuildContext context, WidgetRef ref, BudgetModel b) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete this budget?'),
      content: Text(
          'This removes "${b.name}". Its past spending stays visible on your '
          'transactions, just no longer tracked against a budget.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.critical),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Long-press quick-actions sheet: Edit / Duplicate / Archive / Reset / Delete.
void showBudgetActionsSheet(
    BuildContext context, WidgetRef ref, BudgetModel b, VoidCallback onEdit) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4))),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AppTokens.brand),
            title: const Text('Edit budget'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_outlined, color: AppTokens.brand),
            title: const Text('Duplicate budget'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await ref
                  .read(budgetFormControllerProvider.notifier)
                  .duplicate(b, const Uuid().v4());
            },
          ),
          ListTile(
            leading: const Icon(Icons.refresh, color: AppTokens.brand),
            title: const Text('Reset for next period'),
            subtitle: const Text('Rolls the dates forward, same length',
                style: TextStyle(fontSize: 11)),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await ref
                  .read(budgetFormControllerProvider.notifier)
                  .resetToNextPeriod(b);
            },
          ),
          ListTile(
            leading: Icon(
                b.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                color: AppTokens.warning),
            title: Text(b.isArchived ? 'Restore budget' : 'Archive budget'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await ref
                  .read(budgetFormControllerProvider.notifier)
                  .setStatus(b.id, b.isArchived ? 'Active' : 'Archived');
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_outline, color: AppColors.critical),
            title: const Text('Delete budget',
                style: TextStyle(color: AppColors.critical)),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              if (await _confirmDelete(context, ref, b)) {
                await ref
                    .read(budgetFormControllerProvider.notifier)
                    .delete(b.id);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      ),
    );
  }
}

class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No budgets match your search or filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text("Couldn't load your budgets",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: AppTokens.brand),
            ),
          ],
        ),
      ),
    );
  }
}
