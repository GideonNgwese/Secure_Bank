import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/transaction_model.dart';
import '../../../../utils/constants.dart';
import '../../../accounts/data/account_providers.dart';
import '../../../transactions/data/transaction_providers.dart';
import '../../data/fraud_detection_providers.dart';
import '../../domain/risk_level.dart';
import '../controllers/fraud_review_controller.dart';

/// The Fraud Review Workflow's decision screen — opened right after a
/// Medium+ risk transaction is saved (from the transaction form) or via
/// "Review Now" on a fraud notification. Reads the transaction and its
/// paired fraud alert live, so Approve/Decline anywhere else (another
/// device, the notification action) is reflected here instantly too.
class FraudReviewScreen extends ConsumerStatefulWidget {
  final String userId;
  final String transactionId;
  const FraudReviewScreen(
      {super.key, required this.userId, required this.transactionId});

  @override
  ConsumerState<FraudReviewScreen> createState() => _FraudReviewScreenState();
}

class _FraudReviewScreenState extends ConsumerState<FraudReviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  String? _resultAction; // 'approved' | 'declined' while the result plays

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _act(Future<bool> Function() action, String? resultLabel) async {
    final ok = await action();
    if (!ok || !mounted) return;
    if (resultLabel == null) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _resultAction = resultLabel);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionByIdProvider(widget.transactionId));
    final accounts =
        ref.watch(accountsRawProvider(widget.userId)).valueOrNull ?? [];
    final alerts =
        ref.watch(fraudAlertsProvider(widget.userId)).valueOrNull ?? [];
    final controller = ref.read(fraudReviewControllerProvider.notifier);
    final busy = ref.watch(fraudReviewControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Fraud Review')),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
            child: Text('Unable to load this transaction.')),
        data: (tx) {
          if (tx == null) {
            return const Center(child: Text('Transaction not found.'));
          }
          final level = RiskLevelX.fromName(tx.riskLevel);
          final account =
              accounts.where((a) => a.id == tx.accountId).firstOrNull;
          final alert =
              alerts.where((a) => a.transactionId == tx.id).firstOrNull;
          final pending = tx.isPendingReview;

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _WarningCard(
                    level: level,
                    reason: alert?.reason ?? 'Unusual activity detected.',
                    recommendation: alert?.recommendation ??
                        'Review the details below before deciding.',
                    pulseController: pending ? _pulseController : null,
                  ),
                  const SizedBox(height: 20),
                  _DetailsCard(
                    rows: [
                      ('Amount', '${formatFCFA(tx.amount)} ${tx.currency}'),
                      ('Merchant',
                          tx.merchant.isEmpty ? '—' : tx.merchant),
                      ('Category', tx.category),
                      ('Account', account?.accountName ?? 'Unknown account'),
                      ('Risk Level', level.label),
                      ('Risk Score', '${tx.riskScore}/100'),
                      ('Reason for Flag', alert?.reason ?? '—'),
                      (
                        'Detection Time',
                        DateFormat.yMMMd()
                            .add_jm()
                            .format(alert?.createdAt ?? tx.createdAt)
                      ),
                      ('AI Recommendation', alert?.recommendation ?? '—'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (pending)
                    _ActionButtons(
                      busy: busy,
                      onReviewLater: () =>
                          _act(() => controller.reviewLater(tx), null),
                      onDecline: () =>
                          _act(() => controller.decline(tx), 'declined'),
                      onApprove: () =>
                          _act(() => controller.approve(tx), 'approved'),
                    )
                  else
                    _ResolvedBanner(tx: tx),
                ],
              ),
              if (_resultAction != null) _ResultOverlay(action: _resultAction!),
            ],
          );
        },
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final RiskLevel level;
  final String reason;
  final String recommendation;
  final AnimationController? pulseController;
  const _WarningCard({
    required this.level,
    required this.reason,
    required this.recommendation,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: level.color.withValues(alpha: 0.4), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pulseIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Text('⚠ ${level.label} Risk Transaction Detected',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: level.color)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _line(context, 'Reason', reason),
          const SizedBox(height: 8),
          _line(context, 'Recommendation', recommendation),
        ],
      ),
    );
  }

  Widget _pulseIcon() {
    final icon = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: level.color.withValues(alpha: 0.18), shape: BoxShape.circle),
      child: Icon(level.icon, color: level.color, size: 26),
    );
    if (pulseController == null) return icon;
    return AnimatedBuilder(
      animation: pulseController!,
      builder: (_, child) => Transform.scale(
        scale: 1 + pulseController!.value * 0.14,
        child: child,
      ),
      child: icon,
    );
  }

  Widget _line(BuildContext context, String label, String value) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
        children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final List<(String, String)> rows;
  const _DetailsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(rows[i].$1,
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 13)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(rows[i].$2,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                  if (i != rows.length - 1) const Divider(height: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool busy;
  final VoidCallback onReviewLater;
  final VoidCallback onDecline;
  final VoidCallback onApprove;
  const _ActionButtons({
    required this.busy,
    required this.onReviewLater,
    required this.onDecline,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onDecline,
                style: FilledButton.styleFrom(
                    backgroundColor: AppTokens.danger,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.block_rounded),
                label: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onApprove,
                style: FilledButton.styleFrom(
                    backgroundColor: AppTokens.success,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Approve'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onReviewLater,
            icon: const Icon(Icons.schedule_outlined),
            label: const Text('Review Later'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ],
    );
  }
}

class _ResolvedBanner extends StatelessWidget {
  final TransactionModel tx;
  const _ResolvedBanner({required this.tx});

  @override
  Widget build(BuildContext context) {
    final approved = tx.status == 'Approved';
    final color = approved ? AppTokens.success : AppTokens.danger;
    final reviewedAt = tx.reviewedAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(approved ? Icons.check_circle : Icons.gpp_bad_rounded,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              approved
                  ? 'You approved this transaction'
                      '${reviewedAt != null ? ' on ${DateFormat.yMMMd().add_jm().format(reviewedAt)}' : ''}.'
                  : 'You declined this transaction — it was blocked for your protection'
                      '${reviewedAt != null ? ' on ${DateFormat.yMMMd().add_jm().format(reviewedAt)}' : ''}.',
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  final String action; // 'approved' | 'declined'
  const _ResultOverlay({required this.action});

  @override
  Widget build(BuildContext context) {
    final approved = action == 'approved';
    final color = approved ? AppTokens.success : AppTokens.danger;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (_, v, child) =>
                Transform.scale(scale: v.clamp(0, 1.2), child: child),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(
                      approved ? Icons.check_rounded : Icons.gpp_bad_rounded,
                      color: Colors.white,
                      size: 48),
                ),
                const SizedBox(height: 16),
                Text(
                    approved
                        ? 'Transaction Approved'
                        : 'Transaction Blocked',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
