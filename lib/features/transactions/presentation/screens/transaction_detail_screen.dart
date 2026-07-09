import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/transaction_model.dart';
import '../../../../utils/constants.dart';
import '../../../accounts/data/account_providers.dart';
import '../../data/transaction_providers.dart';
import '../../domain/transaction_fields.dart';
import '../controllers/transaction_form_controller.dart';
import 'transaction_form_screen.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String userId;
  final String transactionId;
  const TransactionDetailScreen(
      {super.key, required this.userId, required this.transactionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(transactionsRawProvider(userId)).valueOrNull ?? [];
    final accounts = ref.watch(accountsRawProvider(userId)).valueOrNull ?? [];
    final tx = txs.where((t) => t.id == transactionId).firstOrNull;

    if (tx == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final account = accounts.where((a) => a.id == tx.accountId).firstOrNull;
    final typeColor = TransactionTypeStyle.colorOf(tx.type);
    final isCredit = tx.type == 'Adjustment'
        ? tx.amount >= 0
        : TransactionTypeStyle.isCredit(tx.type);
    final sign = isCredit ? '+' : '-';
    final isTransfer = tx.type == 'Transfer';

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Hero(
            tag: 'transaction-${tx.id}',
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [typeColor, typeColor.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  boxShadow: [
                    BoxShadow(
                        color: typeColor.withValues(alpha: 0.32),
                        blurRadius: 20,
                        offset: const Offset(0, 12)),
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
                          child: Icon(
                              TransactionCategoryStyle.iconOf(tx.category),
                              color: Colors.white,
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(tx.type,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ),
                        _statusChip(tx.status),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '$sign${formatFCFA(tx.amount.abs())}'
                      '${tx.currency == 'FCFA' ? '' : ' ${tx.currency}'}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tx.title.isNotEmpty
                          ? tx.title
                          : (tx.description.isNotEmpty
                              ? tx.description
                              : tx.category),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                    if (tx.riskLevel != 'Low') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                            '⚠ ${tx.riskLevel} risk (score ${tx.riskScore})',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (tx.receiptUrl.isNotEmpty) ...[
            _receiptCard(context, tx.receiptUrl),
            const SizedBox(height: 20),
          ],
          _detailsCard(context, tx, account?.accountName ?? 'Unknown account'),
          const SizedBox(height: 20),
          if (!isTransfer) ...[
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        TransactionFormScreen(userId: userId, existing: tx))),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit transaction'),
                style: FilledButton.styleFrom(backgroundColor: AppTokens.brand),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextButton.icon(
            onPressed: () => _confirmDelete(context, ref, tx),
            icon: const Icon(Icons.delete_outline, color: AppTokens.danger),
            label: const Text('Delete transaction',
                style: TextStyle(color: AppTokens.danger)),
          ),
        ],
      ),
    );
  }

  Widget _receiptCard(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: InteractiveViewer(child: Image.network(url)),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        child: Image.network(url,
            height: 160, width: double.infinity, fit: BoxFit.cover),
      ),
    );
  }

  Widget _detailsCard(
      BuildContext context, TransactionModel tx, String accountName) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final updated = tx.updatedAt ?? tx.createdAt;
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
          _row(context, 'Category', tx.category),
          _row(context, 'Merchant', tx.merchant.isEmpty ? '—' : tx.merchant),
          _row(context, 'Account', accountName),
          _row(context, 'Payment method',
              tx.paymentMethod.isEmpty ? '—' : tx.paymentMethod),
          _row(context, 'Location', tx.location.isEmpty ? '—' : tx.location),
          _row(context, 'Description',
              tx.description.isEmpty ? '—' : tx.description),
          _row(context, 'Status', tx.status),
          _row(context, 'Date',
              DateFormat.yMMMd().add_jm().format(tx.transactionDate)),
          _row(context, 'Created',
              DateFormat.yMMMd().add_jm().format(tx.createdAt)),
          _row(context, 'Updated', DateFormat.yMMMd().add_jm().format(updated),
              last: true),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool last = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
          if (!last) const Divider(height: 16),
        ],
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

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TransactionModel tx) async {
    final isTransfer = tx.type == 'Transfer';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: Text(isTransfer
            ? 'This is a transfer. Both linked legs (transfer-in and transfer-out) '
                'will be deleted. Balances update automatically.'
            : 'This permanently removes the transaction. Balances update automatically.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTokens.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success =
        await ref.read(transactionFormControllerProvider.notifier).delete(tx);
    if (success && context.mounted) Navigator.of(context).maybePop();
  }
}
