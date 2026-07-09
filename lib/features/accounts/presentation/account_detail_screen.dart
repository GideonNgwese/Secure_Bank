import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../models/account_model.dart';
import '../../../utils/constants.dart';
import '../data/account_providers.dart';
import '../domain/account_view.dart';
import 'account_form_screen.dart';
import 'widgets/account_card.dart';

class AccountDetailScreen extends ConsumerWidget {
  final String userId;
  final String accountId;
  const AccountDetailScreen(
      {super.key, required this.userId, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsRawProvider(userId)).valueOrNull ?? [];
    final txs = ref.watch(accountsTxProvider(userId)).valueOrNull ?? [];
    final repo = ref.watch(accountRepositoryProvider);

    final account = accounts.where((a) => a.id == accountId).firstOrNull;
    if (account == null) {
      // Deleted while open — leave the screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }
    final balance = repo.balanceOf(account, txs);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Account details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AccountCard(item: AccountWithBalance(account, balance)),
          const SizedBox(height: 20),
          _detailsCard(account, balance),
          const SizedBox(height: 20),
          _actions(context, ref, repo, account),
        ],
      ),
    );
  }

  Widget _detailsCard(AccountModel a, double balance) {
    final updated = a.updatedAt ?? a.createdAt;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          _row('Current balance', formatFCFA(balance)),
          _row('Opening balance', formatFCFA(a.openingBalance)),
          _row('Provider', a.provider),
          _row('Type', a.accountType),
          _row('Number', a.maskedNumber.isEmpty ? '—' : a.maskedNumber),
          _row('Currency', a.currency),
          _row('Status', a.status),
          _row('Added', DateFormat.yMMMd().format(a.createdAt)),
          _row('Updated', DateFormat.yMMMd().format(updated), last: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: last ? 8 : 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
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

  Widget _actions(BuildContext context, WidgetRef ref, repo, AccountModel a) {
    return Column(
      children: [
        SizedBox(
          height: 50,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    AccountFormScreen(userId: userId, existing: a))),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit account'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await repo.setStatus(a, a.isArchived ? 'Active' : 'Archived');
              if (context.mounted) Navigator.of(context).maybePop();
            },
            icon: Icon(a.isArchived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined),
            label: Text(a.isArchived ? 'Restore account' : 'Archive account'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => _confirmDelete(context, repo, a),
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          label: const Text('Delete account',
              style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, repo, AccountModel a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this account?'),
        content: Text('This removes "${a.accountName}". Its transactions stay '
            'but will no longer show a linked account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await repo.delete(a.id);
      if (context.mounted) Navigator.of(context).maybePop();
    }
  }
}
