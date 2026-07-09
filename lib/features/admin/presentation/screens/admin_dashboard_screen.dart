import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/domain/auth_user.dart';
import '../../../../models/fraud_alert_model.dart';
import '../../../fraud_detection/domain/chart_data.dart';
import '../../../fraud_detection/domain/risk_level.dart';
import '../../../fraud_detection/presentation/widgets/insight_charts.dart'
    show RiskTrendChart;
import '../../data/admin_providers.dart';
import '../../domain/admin_analytics.dart';
import '../../domain/admin_chart_data.dart';
import '../widgets/admin_stat_card.dart';
import '../widgets/admin_chart_card.dart';

/// The Admin Portal's landing tab — platform health, security, and activity
/// at a glance. Every figure here is a platform-wide aggregate (user counts,
/// alert counts, timestamps); nothing here reads a customer's balance,
/// transaction description, or banking details.
class AdminDashboardScreen extends ConsumerWidget {
  final AuthUser admin;
  const AdminDashboardScreen({super.key, required this.admin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminAuthUsersProvider);
    final alertsAsync = ref.watch(adminAllFraudAlertsProvider);
    final kycAsync = ref.watch(adminKycProvider);
    final logsAsync = ref.watch(adminActivityLogsProvider);

    final users = usersAsync.valueOrNull ?? const <AuthUser>[];
    final alerts = alertsAsync.valueOrNull ?? const [];
    final kyc = kycAsync.valueOrNull ?? const [];
    final logs = logsAsync.valueOrNull ?? const [];

    final stillLoading = usersAsync.isLoading && !usersAsync.hasValue;
    if (stillLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final stats = AdminOverviewStats.build(
        users: users, alerts: alerts, kyc: kyc, now: now);
    final degraded = usersAsync.hasError ||
        alertsAsync.hasError ||
        kycAsync.hasError ||
        logsAsync.hasError;

    final usersById = {for (final u in users) u.uid: u};
    final recentSecurityEvents = alerts
        .where((a) => a.riskLevel == 'High' || a.riskLevel == 'Critical')
        .take(5)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Header(admin: admin, degraded: degraded),
        const SizedBox(height: 20),
        AdminStatGrid(cards: [
          AdminStatCard(
              label: 'Total Users',
              value: '${stats.totalUsers}',
              icon: Icons.people_outline,
              color: AppTokens.brand),
          AdminStatCard(
              label: 'Active Today',
              value: '${stats.activeUsersToday}',
              icon: Icons.bolt_outlined,
              color: AppTokens.success),
          AdminStatCard(
              label: 'New Registrations',
              value: '${stats.newRegistrationsToday}',
              caption: 'today',
              icon: Icons.person_add_alt_outlined,
              color: AppTokens.accent),
          AdminStatCard(
              label: 'Weekly Active',
              value: '${stats.weeklyActiveUsers}',
              icon: Icons.calendar_view_week_outlined,
              color: AppTokens.brandDeep),
          AdminStatCard(
              label: 'Fraud Alerts',
              value: '${stats.fraudAlertsToday}',
              caption: 'today',
              icon: Icons.warning_amber_rounded,
              color: AppTokens.warning),
          AdminStatCard(
              label: 'Pending Fraud Review',
              value: '${stats.pendingFraudReviews}',
              icon: Icons.gavel_outlined,
              color: AppTokens.danger),
          AdminStatCard(
              label: 'Pending KYC',
              value: '${stats.pendingKycReviews}',
              icon: Icons.badge_outlined,
              color: AppTokens.brand),
          AdminStatCard(
              label: 'System Health',
              value: degraded ? 'Degraded' : 'Operational',
              icon: degraded
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              color: degraded ? AppTokens.danger : AppTokens.success),
        ]),
        const SizedBox(height: 24),
        const Text('Analytics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        AdminChartCard(
          title: 'User growth (6 months)',
          points: AdminChartData.userGrowth(users, now),
          color: AppTokens.brand,
        ),
        const SizedBox(height: 12),
        AdminChartCard(
          title: 'Daily active users (7 days)',
          points: AdminChartData.dailyActiveUsers(users, now),
          color: AppTokens.success,
          bars: true,
        ),
        const SizedBox(height: 12),
        AdminChartCard(
          title: 'Monthly registrations',
          points: AdminChartData.monthlyRegistrations(users, now),
          color: AppTokens.accent,
          bars: true,
        ),
        const SizedBox(height: 12),
        RiskTrendChart(points: ChartDataBuilder.riskTrend(alerts, now)),
        const SizedBox(height: 24),
        const Text('Recent security events',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        if (recentSecurityEvents.isEmpty)
          const _EmptyRow(text: 'No high or critical risk alerts recently.')
        else
          _Card(
            child: Column(
              children: [
                for (var i = 0; i < recentSecurityEvents.length; i++) ...[
                  _SecurityEventRow(
                    alert: recentSecurityEvents[i],
                    customerName: usersById[recentSecurityEvents[i].userId]
                            ?.fullName ??
                        'Unknown customer',
                  ),
                  if (i != recentSecurityEvents.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),
        const SizedBox(height: 24),
        const Text('Platform activity',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        if (logs.isEmpty)
          const _EmptyRow(text: 'No activity logged yet.')
        else
          _Card(
            child: Column(
              children: [
                for (var i = 0; i < logs.take(8).length; i++) ...[
                  _ActivityRow(log: logs[i]),
                  if (i != logs.take(8).length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final AuthUser admin;
  final bool degraded;
  const _Header({required this.admin, required this.degraded});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting, ${admin.fullName.split(' ').first}',
                  style:
                      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('SecureBank Platform Administration',
                  style:
                      TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: (degraded ? AppTokens.danger : AppTokens.success)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: degraded ? AppTokens.danger : AppTokens.success,
                    shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(degraded ? 'Degraded' : 'All systems normal',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: degraded ? AppTokens.danger : AppTokens.success)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String text;
  const _EmptyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
      ),
    );
  }
}

class _SecurityEventRow extends StatelessWidget {
  final FraudAlertModel alert;
  final String customerName;
  const _SecurityEventRow({required this.alert, required this.customerName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final level = RiskLevelX.fromName(alert.riskLevel);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: level.color.withValues(alpha: 0.14),
        child: Icon(level.icon, color: level.color, size: 18),
      ),
      title: Text(customerName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(alert.reason,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
      trailing: Text(DateFormat.MMMd().add_jm().format(alert.createdAt),
          style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> log;
  const _ActivityRow({required this.log});

  IconData _iconFor(String action) {
    final a = action.toLowerCase();
    if (a.contains('suspend') || a.contains('reactivat')) return Icons.person;
    if (a.contains('kyc')) return Icons.badge_outlined;
    if (a.contains('fraud')) return Icons.shield_outlined;
    if (a.contains('sent') || a.contains('notification')) {
      return Icons.campaign_outlined;
    }
    if (a.contains('logged in')) return Icons.login;
    if (a.contains('registered')) return Icons.person_add;
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final action = (log['action'] ?? '').toString();
    final created = DateTime.tryParse((log['createdAt'] ?? '').toString());
    return ListTile(
      dense: true,
      leading: Icon(_iconFor(action), size: 18, color: scheme.primary),
      title: Text(action, style: const TextStyle(fontSize: 12.5)),
      trailing: created != null
          ? Text(DateFormat.MMMd().add_jm().format(created),
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant))
          : null,
    );
  }
}
