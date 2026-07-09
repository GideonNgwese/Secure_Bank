import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

/// Displays one entry from the legacy generic `alerts` collection
/// (budget-exceeded notifications) inside the unified Alert Center timeline,
/// styled to match [RiskAlertCard]/[InsightCard] so the feed reads as one
/// system even though budget alerts are still owned by the Budget module.
class BudgetAlertTile extends StatelessWidget {
  final Map<String, dynamic> alert;
  final VoidCallback? onMarkRead;

  const BudgetAlertTile({super.key, required this.alert, this.onMarkRead});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUnread = alert['status'] == 'unread';
    final createdAt =
        DateTime.tryParse(alert['createdAt'] ?? '') ?? DateTime.now();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(
            color: AppTokens.warning.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: AppTokens.warning.withValues(alpha: 0.14),
                shape: BoxShape.circle),
            child: const Icon(Icons.pie_chart_outline,
                color: AppTokens.warning, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert['message'] ?? '',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w500)),
                const SizedBox(height: 4),
                Text(DateFormat.MMMd().add_jm().format(createdAt),
                    style: TextStyle(
                        fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (isUnread && onMarkRead != null)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onMarkRead,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.check, size: 15),
              ),
            ),
        ],
      ),
    );
  }
}
