import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/constants.dart';
import '../../domain/transaction_fields.dart';
import '../../domain/transaction_view.dart';

/// Premium transaction row (Revolut/Apple Wallet style): category icon in a
/// type-colored circle, title/merchant/account/date, amount with sign +
/// color, and a status/risk chip when relevant.
class TransactionCard extends StatelessWidget {
  final TransactionWithAccount item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TransactionCard({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = item.transaction;
    final typeColor = TransactionTypeStyle.colorOf(t.type);
    final flagged = t.riskLevel != 'Low';
    final title = t.title.isNotEmpty
        ? t.title
        : (t.description.isNotEmpty ? t.description : t.category);
    final subtitleParts = [
      if (t.merchant.isNotEmpty) t.merchant,
      item.account?.accountName ?? 'Unknown account',
      DateFormat.yMMMd().format(t.transactionDate),
    ];

    final signed = t.type == 'Adjustment'
        ? t.amount
        : (TransactionTypeStyle.isCredit(t.type) ? t.amount : -t.amount);
    final sign = signed > 0 ? '+' : (signed < 0 ? '-' : '');

    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.04) : scheme.surface,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radius),
            border: Border.all(
              color: flagged
                  ? riskColor(t.riskLevel).withValues(alpha: 0.6)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : scheme.outlineVariant.withValues(alpha: 0.35)),
              width: flagged ? 1.4 : 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(TransactionCategoryStyle.iconOf(t.category),
                    color: typeColor, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitleParts.join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${formatFCFA(signed.abs())}'
                    '${t.currency == 'FCFA' ? '' : ' ${t.currency}'}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: signed == 0 ? scheme.onSurface : typeColor),
                  ),
                  const SizedBox(height: 3),
                  if (!t.isCompleted)
                    _pill(
                        t.status,
                        t.status == 'Failed'
                            ? AppTokens.danger
                            : AppTokens.warning)
                  else if (flagged)
                    _pill('${t.riskLevel} risk', riskColor(t.riskLevel))
                  else
                    Text(t.receiptUrl.isNotEmpty ? '📎' : '',
                        style: const TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9.5, color: color, fontWeight: FontWeight.w600)),
      );
}
