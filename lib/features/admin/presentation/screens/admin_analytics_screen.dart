import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../fraud_detection/domain/chart_data.dart';
import '../../../fraud_detection/presentation/widgets/insight_charts.dart'
    show RiskTrendChart;
import '../../data/admin_providers.dart';
import '../../domain/admin_analytics.dart';
import '../../domain/admin_chart_data.dart';
import '../widgets/admin_chart_card.dart';
import '../widgets/admin_stat_card.dart';

/// Deeper, rate-oriented analytics beyond the Dashboard's at-a-glance
/// charts: KYC approval rate, notification engagement, weekly active users.
/// User growth / monthly registrations / fraud trend already live on the
/// Dashboard — not duplicated here as full charts, just referenced via
/// their headline numbers.
class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminAuthUsersProvider).valueOrNull ?? [];
    final alerts = ref.watch(adminAllFraudAlertsProvider).valueOrNull ?? [];
    final kyc = ref.watch(adminKycProvider).valueOrNull ?? [];
    final allNotifications =
        ref.watch(adminAllNotificationsProvider).valueOrNull ?? [];

    final now = DateTime.now();
    final kycStats = KycStats.build(kyc);
    final notificationStats = NotificationStats.build(
        allNotifications.where((n) => n.adminNotificationId.isNotEmpty).toList());
    final customers = users.where((u) => !u.isAdmin).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('KYC approval rate',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        AdminStatGrid(cards: [
          AdminStatCard(
              label: 'Approval Rate',
              value: '${kycStats.approvalRatePct.toStringAsFixed(0)}%',
              icon: Icons.verified_outlined,
              color: AppTokens.success),
          AdminStatCard(
              label: 'Approved',
              value: '${kycStats.approved}',
              icon: Icons.check_circle_outline,
              color: AppTokens.success),
          AdminStatCard(
              label: 'Rejected',
              value: '${kycStats.rejected}',
              icon: Icons.cancel_outlined,
              color: AppTokens.danger),
          AdminStatCard(
              label: 'Pending',
              value: '${kycStats.pending}',
              icon: Icons.hourglass_empty,
              color: AppTokens.warning),
        ]),
        const SizedBox(height: 24),
        const Text('Notification engagement',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        AdminStatGrid(cards: [
          AdminStatCard(
              label: 'Delivered',
              value: '${notificationStats.delivered}',
              icon: Icons.mark_email_read_outlined,
              color: AppTokens.brand),
          AdminStatCard(
              label: 'Read Rate',
              value: '${notificationStats.readRatePct.toStringAsFixed(0)}%',
              icon: Icons.visibility_outlined,
              color: AppTokens.accent),
          AdminStatCard(
              label: 'Response Rate',
              value: '${notificationStats.responseRatePct.toStringAsFixed(0)}%',
              icon: Icons.reply_outlined,
              color: AppTokens.success),
          AdminStatCard(
              label: 'Resolved',
              value: '${notificationStats.resolved}',
              icon: Icons.task_alt_outlined,
              color: AppTokens.brandDeep),
        ]),
        const SizedBox(height: 24),
        const Text('Fraud statistics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        AdminStatGrid(cards: [
          AdminStatCard(
              label: 'Total Alerts',
              value: '${alerts.length}',
              icon: Icons.gpp_maybe_outlined,
              color: AppTokens.warning),
          AdminStatCard(
              label: 'Critical',
              value: '${alerts.where((a) => a.riskLevel == 'Critical').length}',
              icon: Icons.dangerous_outlined,
              color: AppTokens.danger),
          AdminStatCard(
              label: 'Resolved',
              value: '${alerts.where((a) => a.adminReviewStatus == 'resolved').length}',
              icon: Icons.check_circle_outline,
              color: AppTokens.success),
          AdminStatCard(
              label: 'False Positives',
              value:
                  '${alerts.where((a) => a.adminReviewStatus == 'false_positive').length}',
              icon: Icons.block_flipped,
              color: Colors.grey),
        ]),
        const SizedBox(height: 12),
        RiskTrendChart(points: ChartDataBuilder.riskTrend(alerts, now)),
        const SizedBox(height: 24),
        const Text('Weekly active users',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        AdminChartCard(
          title: 'Weekly active users (8 weeks)',
          points: AdminChartData.weeklyActiveUsers(customers, now),
          color: AppTokens.success,
        ),
      ],
    );
  }
}
