import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/header_provider.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../models/account_model.dart';
import '../../../models/transaction_model.dart';
import '../../../utils/constants.dart';
import '../../../screens/profile/profile_kyc_screen.dart';
import '../../fraud_detection/data/fraud_detection_providers.dart';
import '../../fraud_detection/presentation/screens/fraud_center_screen.dart';
import '../../fraud_detection/presentation/screens/fraud_review_screen.dart';
import '../../notifications/presentation/screens/notifications_screen.dart';
import '../../settings/presentation/screens/settings_screen.dart';
import '../../transactions/domain/transaction_fields.dart';
import '../../transactions/presentation/screens/transaction_form_screen.dart';
import '../data/dashboard_providers.dart';
import '../domain/dashboard_data.dart';
import 'widgets/dashboard_skeleton.dart';

const _navy = Color(0xFF0A1B3D);
const _navyDeep = Color(0xFF071228);

class DashboardScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final void Function(int index)? onNavigateToTab;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.onNavigateToTab,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _hideBalance = false;
  int _analyticsTab = 0; // 0 = spending, 1 = income vs expense
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _openAlerts() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FraudCenterScreen(userId: widget.userId)));

  void _openProfile() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProfileKycScreen(userId: widget.userId)));

  void _openNotifications() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NotificationsScreen(userId: widget.userId)));

  void _openReview(String transactionId) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FraudReviewScreen(
              userId: widget.userId, transactionId: transactionId)));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dashboardDataProvider(widget.userId));
    final headerData = async.valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          PremiumHeader(
            userId: widget.userId,
            title: '$_greeting, ${widget.userName.split(' ').first}',
            subtitle: 'Here is your financial overview',
            variant: HeaderVariant.gradient,
            scrollController: _scrollController,
            onAvatarTap: _openProfile,
            onNotificationsTap: _openNotifications,
            onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(userId: widget.userId))),
            stats: headerData == null
                ? null
                : [
                    HeaderStat('Balance', formatFCFA(headerData.totalBalance)),
                    HeaderStat('Income', formatFCFA(headerData.income),
                        valueColor: const Color(0xFF4ADE80)),
                    HeaderStat('Expenses', formatFCFA(headerData.expense),
                        valueColor: const Color(0xFFFF8A8A)),
                  ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: async.when(
                loading: () => const DashboardSkeleton(),
                error: (e, _) => _ErrorState(onRetry: () {
                  ref.invalidate(dashboardAccountsProvider(widget.userId));
                  ref.invalidate(dashboardTransactionsProvider(widget.userId));
                }),
                data: (data) => RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(dashboardAccountsProvider(widget.userId));
                    ref.invalidate(
                        dashboardTransactionsProvider(widget.userId));
                  },
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (data.pendingReviewCount > 0) ...[
                        FadeSlideIn(
                          child: _PendingReviewBanner(
                            count: data.pendingReviewCount,
                            onTap: () {
                              final tx =
                                  data.pendingReviewTransactions.firstOrNull;
                              if (tx != null) _openReview(tx.id);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      FadeSlideIn(
                        child: _BalanceCard(
                          data: data,
                          hidden: _hideBalance,
                          onToggleHide: () =>
                              setState(() => _hideBalance = !_hideBalance),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _QuickActions(
                        onSend: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => TransactionFormScreen(
                                    userId: widget.userId,
                                    initialType: 'Transfer'))),
                        onAddAccount: () => widget.onNavigateToTab?.call(1),
                        onTransactions: () => widget.onNavigateToTab?.call(2),
                        onBudget: () => widget.onNavigateToTab?.call(3),
                      ),
                      const SizedBox(height: 22),
                      _SectionTitle('Security',
                          action: 'View all', onAction: _openAlerts),
                      const SizedBox(height: 10),
                      _SecuritySummaryCard(
                          userId: widget.userId, onView: _openAlerts),
                      if (data.flaggedCount > 0) ...[
                        const SizedBox(height: 12),
                        _FraudCard(data: data, onView: _openAlerts),
                      ],
                      const SizedBox(height: 12),
                      _FraudReviewsSummaryCard(data: data),
                      const SizedBox(height: 22),
                      _SectionTitle('Your accounts',
                          action: 'See all',
                          onAction: () => widget.onNavigateToTab?.call(1)),
                      const SizedBox(height: 10),
                      _AccountCarousel(
                          // Active only, so the carousel's balances always
                          // reconcile with the Total Balance figure above —
                          // inactive/archived accounts are still reachable
                          // from the full Accounts tab.
                          accounts: data.accounts
                              .where((a) => a.account.isActive)
                              .toList(),
                          hidden: _hideBalance),
                      const SizedBox(height: 22),
                      _SectionTitle('Analytics'),
                      const SizedBox(height: 10),
                      _AnalyticsCard(
                        data: data,
                        tab: _analyticsTab,
                        onTab: (i) => setState(() => _analyticsTab = i),
                      ),
                      if (data.insights.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _SectionTitle('Smart insights'),
                        const SizedBox(height: 10),
                        _Insights(insights: data.insights),
                      ],
                      const SizedBox(height: 22),
                      _SectionTitle('Recent transactions',
                          action: 'View all',
                          onAction: () => widget.onNavigateToTab?.call(2)),
                      const SizedBox(height: 10),
                      _RecentTransactions(data: data),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------- Balance card -----------------------------

class _BalanceCard extends StatelessWidget {
  final DashboardData data;
  final bool hidden;
  final VoidCallback onToggleHide;
  const _BalanceCard(
      {required this.data, required this.hidden, required this.onToggleHide});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, _navyDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: _navy.withValues(alpha: 0.4),
              blurRadius: 26,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Stack(
        children: [
          // glass highlight
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Total Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const Spacer(),
                  GestureDetector(
                    onTap: onToggleHide,
                    child: Icon(
                        hidden ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white70,
                        size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              hidden
                  ? const Text('••••••••',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2))
                  : TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: data.totalBalance),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text(formatFCFA(v),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _miniStat('Income', data.income, const Color(0xFF4ADE80),
                      Icons.south_west, hidden),
                  _divider(),
                  _miniStat('Expenses', data.expense, const Color(0xFFFF8A8A),
                      Icons.north_east, hidden),
                  _divider(),
                  _miniStat('Savings', data.savings, const Color(0xFF64C8FF),
                      Icons.savings_outlined, hidden),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 34, color: Colors.white.withValues(alpha: 0.12));

  Widget _miniStat(
      String label, double value, Color color, IconData icon, bool hidden) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(hidden ? '••••' : formatFCFA(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ----------------------------- Quick actions -----------------------------

class _QuickActions extends StatelessWidget {
  final VoidCallback onSend, onAddAccount, onTransactions, onBudget;
  const _QuickActions({
    required this.onSend,
    required this.onAddAccount,
    required this.onTransactions,
    required this.onBudget,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.send_rounded, 'Send', onSend),
      (Icons.add_card_outlined, 'Account', onAddAccount),
      (Icons.receipt_long_outlined, 'Activity', onTransactions),
      (Icons.pie_chart_outline, 'Budget', onBudget),
    ];
    return Row(
      children: [
        for (final a in actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _ActionCard(icon: a.$1, label: a.$2, onTap: a.$3),
            ),
          ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionCard(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------- Account carousel -----------------------------

class _AccountCarousel extends StatelessWidget {
  final List<AccountBalance> accounts;
  final bool hidden;
  const _AccountCarousel({required this.accounts, required this.hidden});

  static const _gradients = [
    [Color(0xFF2E5BFF), Color(0xFF7A2BE2)],
    [Color(0xFF7A2BE2), Color(0xFFE0218A)],
    [Color(0xFF0A1B3D), Color(0xFF2E5BFF)],
    [Color(0xFF00B4DB), Color(0xFF1FA96A)],
  ];

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const _EmptyBox(
          icon: Icons.account_balance_wallet_outlined,
          text: 'No accounts yet. Add one to get started.');
    }
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final ab = accounts[i];
          final g = _gradients[i % _gradients.length];
          return Container(
            width: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: g,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: g.last.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(ab.account.accountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                    _statusDot(ab.account.status),
                  ],
                ),
                Text(ab.account.accountType,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 11)),
                const Spacer(),
                Text(
                    ab.account.maskedNumber.isEmpty
                        ? '•••• ••••'
                        : ab.account.maskedNumber,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(hidden ? '••••••' : formatFCFA(ab.balance),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusDot(String status) {
    final active = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(active ? 'Active' : 'Inactive',
          style: const TextStyle(color: Colors.white, fontSize: 9)),
    );
  }
}

// ----------------------------- Analytics -----------------------------

class _AnalyticsCard extends StatelessWidget {
  final DashboardData data;
  final int tab;
  final ValueChanged<int> onTab;
  const _AnalyticsCard(
      {required this.data, required this.tab, required this.onTab});

  static const _palette = [
    AppColors.primary,
    AppColors.accent,
    Color(0xFFE0218A),
    Color(0xFF00B4DB),
    Color(0xFF1FA96A),
    Color(0xFFE8A33D),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              _tabChip('Spending', 0),
              const SizedBox(width: 8),
              _tabChip('Income vs Expense', 1),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 190, child: tab == 0 ? _pie() : _bars()),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int i) {
    final selected = tab == i;
    return GestureDetector(
      onTap: () => onTab(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.primary)),
      ),
    );
  }

  Widget _pie() {
    final entries = data.spendingByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) {
      return const _EmptyBox(
          icon: Icons.pie_chart_outline,
          text: 'No spending recorded this month.');
    }
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 42,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value,
                    color: _palette[i % _palette.length],
                    title:
                        '${(entries[i].value / total * 100).toStringAsFixed(0)}%',
                    radius: 52,
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < entries.length && i < 5; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: _palette[i % _palette.length],
                              borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(entries[i].key,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bars() {
    final trend = data.trend;
    var maxY = 0.0;
    for (final t in trend) {
      maxY = [maxY, t.income, t.expense].reduce((a, b) => a > b ? a : b);
    }
    if (maxY == 0) maxY = 1000;
    return BarChart(
      BarChartData(
        maxY: maxY * 1.25,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(trend[i].label,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < trend.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                  toY: trend[i].income,
                  color: AppColors.success,
                  width: 7,
                  borderRadius: BorderRadius.circular(3)),
              BarChartRodData(
                  toY: trend[i].expense,
                  color: AppColors.danger,
                  width: 7,
                  borderRadius: BorderRadius.circular(3)),
            ]),
        ],
      ),
    );
  }
}

// ----------------------------- Security summary -----------------------------

/// Current risk level, live fraud score, security status, and the most
/// recent suspicious activity — always visible (unlike [_FraudCard], which
/// only appears when this month has flagged transactions), all fed by the
/// same live providers the header shield and Fraud Center already use.
class _SecuritySummaryCard extends ConsumerWidget {
  final String userId;
  final VoidCallback onView;
  const _SecuritySummaryCard({required this.userId, required this.onView});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(headerSecurityScoreProvider(userId));
    final status = ref.watch(headerSecurityStatusProvider(userId));
    final recent = ref
            .watch(notificationsProvider(userId))
            .valueOrNull
            ?.where((n) => !n.dismissed)
            .take(3)
            .toList() ??
        const [];
    final isSecure = status == SecurityStatus.secure;
    final tone = isSecure ? AppColors.success : AppColors.danger;

    return GestureDetector(
      onTap: onView,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(
                      isSecure
                          ? Icons.verified_user_rounded
                          : Icons.gpp_maybe_rounded,
                      color: tone),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isSecure ? 'Account secure' : 'Attention needed',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: tone)),
                      Text('Security score: $score/100',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
            if (recent.isNotEmpty) ...[
              const Divider(height: 20),
              for (final n in recent)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                            color: riskColor(n.riskLevel),
                            shape: BoxShape.circle),
                      ),
                      Expanded(
                        child: Text(n.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------------------- Fraud card -----------------------------

class _FraudCard extends StatefulWidget {
  final DashboardData data;
  final VoidCallback onView;
  const _FraudCard({required this.data, required this.onView});

  @override
  State<_FraudCard> createState() => _FraudCardState();
}

class _FraudCardState extends State<_FraudCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final high = widget.data.flagged.where((t) => t.riskLevel == 'High').length;
    final tone = high > 0 ? AppColors.danger : AppColors.warning;
    return GestureDetector(
      onTap: widget.onView,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: tone.withValues(alpha: 0.18 + 0.14 * _pulse.value),
                  blurRadius: 16 + 8 * _pulse.value),
            ],
          ),
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tone.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.16),
                    shape: BoxShape.circle),
                child: Icon(Icons.gpp_maybe_outlined, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${widget.data.flaggedCount} suspicious activit'
                        '${widget.data.flaggedCount == 1 ? 'y' : 'ies'} detected',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: tone,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    const Text('Tap to review flagged transactions',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tone),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------- Pending review banner -----------------------------

/// "Security Review Required" banner — appears only while at least one
/// transaction is awaiting the user's Approve/Decline decision. An amber
/// pulse (same animated-glow pattern as [_FraudCard]) keeps it noticeable
/// without being alarming the way the red fraud card is.
class _PendingReviewBanner extends StatefulWidget {
  final int count;
  final VoidCallback onTap;
  const _PendingReviewBanner({required this.count, required this.onTap});

  @override
  State<_PendingReviewBanner> createState() => _PendingReviewBannerState();
}

class _PendingReviewBannerState extends State<_PendingReviewBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  static const _amber = Color(0xFFE8A33D);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: _amber.withValues(alpha: 0.16 + 0.14 * _pulse.value),
                  blurRadius: 14 + 6 * _pulse.value),
            ],
          ),
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _amber.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.18),
                    shape: BoxShape.circle),
                child: const Icon(Icons.shield_outlined, color: _amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Security Review Required',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13.5)),
                    Text(
                        '${widget.count} pending transaction'
                        '${widget.count == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _amber),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------- Fraud reviews summary -----------------------------

/// Pending / Approved / Declined live counts for the Fraud Review Workflow —
/// always visible in the Security section, separate from [_SecuritySummaryCard]
/// (overall risk posture) and [_FraudCard] (unresolved flags needing a look).
class _FraudReviewsSummaryCard extends StatelessWidget {
  final DashboardData data;
  const _FraudReviewsSummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Row(
        children: [
          _stat('Pending', data.pendingReviewCount, AppColors.warning),
          _divider(),
          _stat('Approved', data.approvedReviewCount, AppColors.success),
          _divider(),
          _stat('Declined', data.declinedReviewCount, AppColors.danger),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1,
      height: 34,
      color: AppColors.textMuted.withValues(alpha: 0.15));

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ----------------------------- Insights -----------------------------

class _Insights extends StatelessWidget {
  final List<Insight> insights;
  const _Insights({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final i in insights)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: _cardDecoration,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: i.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(i.icon, color: i.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(i.text, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
      ],
    );
  }
}

// ----------------------------- Recent transactions -----------------------------

class _RecentTransactions extends StatelessWidget {
  final DashboardData data;
  const _RecentTransactions({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.recent.isEmpty) {
      return const _EmptyBox(
          icon: Icons.receipt_long_outlined, text: 'No transactions yet.');
    }
    final byId = {for (final a in data.accounts) a.account.id: a.account};
    return Container(
      decoration: _cardDecoration,
      child: Column(
        children: [
          for (var i = 0; i < data.recent.length; i++) ...[
            _row(data.recent[i], byId),
            if (i != data.recent.length - 1)
              const Divider(height: 1, indent: 60),
          ],
        ],
      ),
    );
  }

  Widget _row(TransactionModel tx, Map<String, AccountModel> byId) {
    final isIncome = tx.type == 'Income' || tx.category == 'Transfer In';
    final color = isIncome ? AppColors.success : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(TransactionCategoryStyle.iconOf(tx.category),
                color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.description.isEmpty ? tx.category : tx.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                    '${tx.category} • ${DateFormat.MMMd().format(tx.transactionDate)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isIncome ? '+' : '-'}${formatFCFA(tx.amount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 13)),
              if (tx.riskLevel != 'Low')
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: riskColor(tx.riskLevel).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('${tx.riskLevel} risk',
                      style: TextStyle(
                          fontSize: 9, color: riskColor(tx.riskLevel))),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------- Shared bits -----------------------------

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  boxShadow: [
    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10),
  ],
);

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ),
      ],
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 30),
          const SizedBox(height: 8),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text("Couldn't load your dashboard",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
