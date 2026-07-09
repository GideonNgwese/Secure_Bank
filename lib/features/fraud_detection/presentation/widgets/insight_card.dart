import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/financial_insight_model.dart';

/// A single smart-insight card (spending trend, savings change, income
/// diversity, category overspend). Color and icon follow [sentiment].
class InsightCard extends StatelessWidget {
  final FinancialInsightModel insight;
  final VoidCallback? onMarkRead;
  final VoidCallback? onDismiss;

  const InsightCard({
    super.key,
    required this.insight,
    this.onMarkRead,
    this.onDismiss,
  });

  ({Color color, IconData icon}) get _style => switch (insight.sentiment) {
        'positive' => (
            color: AppTokens.success,
            icon: Icons.trending_up_rounded
          ),
        'warning' => (color: AppTokens.warning, icon: Icons.info_outline),
        _ => (color: AppTokens.brand, icon: Icons.insights_outlined),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _style;
    final dismissed = insight.status == 'dismissed';

    return Opacity(
      opacity: dismissed ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle),
              child: Icon(style.icon, color: style.color, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(insight.title,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: insight.isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600)),
                      ),
                      if (insight.isUnread)
                        Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                                color: AppTokens.brand,
                                shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(insight.message,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          height: 1.35)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(DateFormat.MMMd().format(insight.createdAt),
                          style: TextStyle(
                              fontSize: 10, color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      if (!dismissed && insight.isUnread && onMarkRead != null)
                        _iconButton(Icons.check, onMarkRead!),
                      if (!dismissed && onDismiss != null)
                        _iconButton(Icons.close, onDismiss!),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 15),
      ),
    );
  }
}
