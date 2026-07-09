import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/constants.dart';
import '../../domain/budget_fields.dart';
import '../../domain/budget_view.dart';

/// Premium budget card (Revolut/YNAB style): category icon, name, animated
/// progress bar color-coded by tier, spent/remaining, days left, and a
/// status badge.
class BudgetCard extends StatelessWidget {
  final BudgetWithProgress item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BudgetCard(
      {super.key, required this.item, this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = item.budget;
    final color = Color(b.color);
    final tierColor = item.tier.color;
    final archived = b.isArchived;

    return Opacity(
      opacity: archived ? 0.6 : 1,
      child: Material(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : scheme.outlineVariant.withValues(alpha: 0.4)),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4)),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Hero(
                      tag: 'budget-icon-${b.id}',
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            shape: BoxShape.circle),
                        child: Icon(BudgetFields.iconFor(b),
                            color: color, size: 19),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14.5)),
                          Text('${b.category} • ${b.period}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    _statusBadge(item.displayStatus, tierColor),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(
                        begin: 0, end: (item.percentUsed / 100).clamp(0, 1)),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => LinearProgressIndicator(
                      value: t,
                      minHeight: 9,
                      backgroundColor:
                          scheme.outlineVariant.withValues(alpha: 0.2),
                      color: tierColor,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${formatFCFA(item.spentAmount)} of ${formatFCFA(b.budgetAmount)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ),
                    Text('${item.percentUsed.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: tierColor)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.remainingAmount >= 0
                          ? '${formatFCFA(item.remainingAmount)} remaining'
                          : '${formatFCFA(item.remainingAmount.abs())} over budget',
                      style: TextStyle(
                          fontSize: 11,
                          color: item.remainingAmount >= 0
                              ? scheme.onSurfaceVariant
                              : AppColors.critical,
                          fontWeight: item.remainingAmount < 0
                              ? FontWeight.w600
                              : FontWeight.normal),
                    ),
                    if (!item.isEnded)
                      Text('${item.daysRemaining}d left',
                          style: TextStyle(
                              fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status, Color tierColor) {
    final color = status == 'Archived'
        ? Colors.grey
        : status == 'Completed'
            ? AppColors.primary
            : tierColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8)),
      child: Text(status,
          style: TextStyle(
              fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
    );
  }
}
