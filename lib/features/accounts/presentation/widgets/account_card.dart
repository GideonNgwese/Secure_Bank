import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../utils/constants.dart';
import '../../domain/account_view.dart';

/// Premium gradient account card (Revolut/Wise style). Branding is derived from
/// the provider for consistency. Never shows a full account number.
class AccountCard extends StatelessWidget {
  final AccountWithBalance item;
  final bool hideBalance;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AccountCard({
    super.key,
    required this.item,
    this.hideBalance = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final a = item.account;
    final brand = ProviderBranding.of(a.provider, a.accountType);
    final dimmed = !a.isActive;
    final updated = a.updatedAt ?? a.createdAt;

    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Hero(
        tag: 'account-${a.id}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: brand.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: brand.gradient.last.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(brand.icon, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.accountName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            Text('${a.provider} • ${a.accountType}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      _statusChip(a.status),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    a.maskedNumber.isEmpty ? '•••• ••••' : a.maskedNumber,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13, letterSpacing: 2),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          hideBalance
                              ? '••••••'
                              : '${formatFCFA(item.balance)}'
                                  '${a.currency == 'FCFA' ? '' : ' ${a.currency}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text('Updated ${DateFormat.MMMd().format(updated)}',
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status,
          style: const TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}
