import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/fraud_alert_model.dart';
import '../../../fraud_detection/domain/chart_data.dart';
import '../../../fraud_detection/domain/risk_level.dart';
import '../../../fraud_detection/presentation/widgets/insight_charts.dart'
    show RiskTrendChart;
import '../../data/admin_providers.dart';

/// Filter chip values in display order: 'all' (no filter), then '' (New —
/// not yet triaged), then each admin triage status.
const _kFilterValues = ['all', '', 'under_review', 'resolved', 'false_positive', 'escalated'];

String _statusLabel(String s) => switch (s) {
      'under_review' => 'Under Review',
      'resolved' => 'Resolved',
      'false_positive' => 'False Positive',
      'escalated' => 'Escalated',
      _ => 'New',
    };

Color _statusColor(String s) => switch (s) {
      'under_review' => AppTokens.warning,
      'resolved' => AppTokens.success,
      'false_positive' => Colors.grey,
      'escalated' => AppTokens.danger,
      _ => AppTokens.brand,
    };

/// Fraud Monitoring Center — every fraud_alerts doc platform-wide, with the
/// admin's own investigation triage (separate from the account owner's own
/// Approve/Decline review — see [FraudAlertModel] doc). Shows only what the
/// spec allows: customer name, risk level/score, reason, detection time,
/// status — never the underlying transaction's amount or description.
class AdminFraudMonitoringScreen extends ConsumerStatefulWidget {
  final String adminId;
  const AdminFraudMonitoringScreen({super.key, required this.adminId});

  @override
  ConsumerState<AdminFraudMonitoringScreen> createState() =>
      _AdminFraudMonitoringScreenState();
}

class _AdminFraudMonitoringScreenState
    extends ConsumerState<AdminFraudMonitoringScreen> {
  String _statusFilter = 'all'; // one of _kFilterValues

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(adminAllFraudAlertsProvider);
    final users = ref.watch(adminAuthUsersProvider).valueOrNull ?? [];
    final namesById = {for (final u in users) u.uid: u.fullName};

    return alertsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (allAlerts) {
        final filtered = _statusFilter == 'all'
            ? allAlerts
            : allAlerts
                .where((a) => a.adminReviewStatus == _statusFilter)
                .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            RiskTrendChart(
                points: ChartDataBuilder.riskTrend(allAlerts, DateTime.now())),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final v in _kFilterValues)
                    _filterChip(v == 'all' ? 'All' : _statusLabel(v), v),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('No alerts in this view.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              )
            else
              for (final alert in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AlertCard(
                    alert: alert,
                    customerName: namesById[alert.userId] ?? 'Unknown customer',
                    adminId: widget.adminId,
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _filterChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _statusFilter == value,
        onSelected: (_) => setState(() => _statusFilter = value),
      ),
    );
  }
}

class _AlertCard extends ConsumerWidget {
  final FraudAlertModel alert;
  final String customerName;
  final String adminId;
  const _AlertCard(
      {required this.alert, required this.customerName, required this.adminId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final level = RiskLevelX.fromName(alert.riskLevel);
    final statusColor = _statusColor(alert.adminReviewStatus);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: level.color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(level.icon, color: level.color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(customerName,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_statusLabel(alert.adminReviewStatus),
                    style: TextStyle(
                        fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _badge('${level.label} risk', level.color),
              const SizedBox(width: 6),
              _badge('Score ${alert.riskScore}', scheme.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 8),
          Text(alert.reason, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text(DateFormat.yMMMd().add_jm().format(alert.createdAt),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          if (alert.adminReviewNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Note: ${alert.adminReviewNote}',
                style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _showAlertDetail(context),
                child: const Text('View', style: TextStyle(fontSize: 12)),
              ),
              PopupMenuButton<String>(
                tooltip: 'Update status',
                onSelected: (v) => _update(context, ref, v),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'under_review', child: Text('Mark Under Review')),
                  PopupMenuItem(value: 'resolved', child: Text('Mark Resolved')),
                  PopupMenuItem(value: 'false_positive', child: Text('Mark False Positive')),
                  PopupMenuItem(value: 'escalated', child: Text('Escalate')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: AppTokens.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Update', style: TextStyle(fontSize: 12, color: AppTokens.brand)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 16, color: AppTokens.brand),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
      );

  void _showAlertDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customerName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Risk level: ${alert.riskLevel} (score ${alert.riskScore})'),
            const SizedBox(height: 8),
            Text('Reason: ${alert.reason}'),
            const SizedBox(height: 8),
            Text('Detected: ${DateFormat.yMMMd().add_jm().format(alert.createdAt)}'),
            const SizedBox(height: 8),
            Text('Status: ${_statusLabel(alert.adminReviewStatus)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _update(BuildContext context, WidgetRef ref, String status) async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text('Mark as ${_statusLabel(status)}'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Add context for this decision'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Confirm')),
          ],
        );
      },
    );
    if (note == null) return;
    await ref.read(adminRepositoryProvider).updateFraudAlertAdminReview(
          alertId: alert.id,
          adminReviewStatus: status,
          adminId: adminId,
          note: note,
        );
  }
}
