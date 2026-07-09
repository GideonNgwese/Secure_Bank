import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/fraud_alert_model.dart';
import '../../domain/risk_level.dart';

/// A single fraud/risk alert, styled like a Monzo/Revolut risk notification:
/// colored badge, plain-language reason + recommendation, and mark-read /
/// dismiss actions. Unread alerts are visually emphasized.
class RiskAlertCard extends StatelessWidget {
  final FraudAlertModel alert;
  final VoidCallback? onTap;
  final VoidCallback? onMarkRead;
  final VoidCallback? onDismiss;
  // Fraud Review Workflow: shown instead of (alongside) Mark read/Dismiss
  // when this alert's transaction is still awaiting the user's decision.
  final VoidCallback? onReviewNow;

  const RiskAlertCard({
    super.key,
    required this.alert,
    this.onTap,
    this.onMarkRead,
    this.onDismiss,
    this.onReviewNow,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final level = RiskLevelX.fromName(alert.riskLevel);
    final dismissed = alert.status == 'dismissed';

    return Opacity(
      opacity: dismissed ? 0.55 : 1,
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radius),
              border: Border.all(
                  color: level.color.withValues(alpha: 0.4), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Hero(
                      tag: 'fraud-alert-${alert.id}',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: level.color.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(level.icon, color: level.color, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          _badge('${level.label} risk', level.color),
                          const SizedBox(width: 6),
                          _badge('Score ${alert.riskScore}',
                              scheme.onSurfaceVariant),
                          if (alert.isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                    color: AppTokens.brand,
                                    shape: BoxShape.circle)),
                          ],
                        ],
                      ),
                    ),
                    Text(DateFormat.MMMd().add_jm().format(alert.createdAt),
                        style: TextStyle(
                            fontSize: 10, color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(alert.reason,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: alert.isUnread
                            ? FontWeight.w600
                            : FontWeight.normal)),
                if (alert.recommendation.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: level.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline,
                            size: 14, color: level.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(alert.recommendation,
                              style: TextStyle(
                                  fontSize: 11.5, color: scheme.onSurface)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!dismissed && onReviewNow != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onReviewNow,
                      style: FilledButton.styleFrom(
                          backgroundColor: level.color,
                          padding: const EdgeInsets.symmetric(vertical: 10)),
                      icon: const Icon(Icons.gavel_outlined, size: 16),
                      label: const Text('Review Now'),
                    ),
                  ),
                ],
                if (!dismissed &&
                    (onMarkRead != null ||
                        onDismiss != null ||
                        onReviewNow != null)) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (alert.isUnread && onMarkRead != null)
                        TextButton.icon(
                          onPressed: onMarkRead,
                          icon: const Icon(Icons.check, size: 15),
                          label: const Text('Mark read',
                              style: TextStyle(fontSize: 12)),
                        ),
                      if (onDismiss != null)
                        TextButton.icon(
                          onPressed: onDismiss,
                          icon: const Icon(Icons.close, size: 15),
                          label: const Text('Dismiss',
                              style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                              foregroundColor: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
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
            style: TextStyle(
                fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
      );
}
