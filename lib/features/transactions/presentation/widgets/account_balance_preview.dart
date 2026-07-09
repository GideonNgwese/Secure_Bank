import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/constants.dart';
import '../../../accounts/data/account_providers.dart';

/// Live "current balance → balance after this transaction" preview, shown
/// in the Add/Edit Transaction form as the user picks an account/amount/type
/// — reuses the accounts feature's own balance calculation so it's always
/// consistent with what the Accounts tab shows.
class AccountBalancePreview extends ConsumerWidget {
  final String userId;
  final String accountId;
  final double delta;

  const AccountBalancePreview({
    super.key,
    required this.userId,
    required this.accountId,
    required this.delta,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsRawProvider(userId)).valueOrNull ?? [];
    final txs = ref.watch(accountsTxProvider(userId)).valueOrNull ?? [];
    final repo = ref.watch(accountRepositoryProvider);
    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) return const SizedBox.shrink();

    final current = repo.balanceOf(account, txs);
    final projected = current + delta;
    final scheme = Theme.of(context).colorScheme;
    final up = delta > 0;
    final flat = delta == 0;
    final deltaColor = flat
        ? scheme.onSurfaceVariant
        : (up ? AppTokens.success : AppTokens.danger);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.accountName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12.5)),
                const SizedBox(height: 2),
                Text('${formatFCFA(current)}  →  ${formatFCFA(projected)}',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (!flat)
            Row(
              children: [
                Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14, color: deltaColor),
                Text(formatFCFA(delta.abs()),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: deltaColor)),
              ],
            ),
        ],
      ),
    );
  }
}
