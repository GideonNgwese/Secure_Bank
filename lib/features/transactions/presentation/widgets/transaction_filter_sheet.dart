import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/account_model.dart';
import '../../data/transaction_providers.dart';
import '../../domain/transaction_fields.dart';

/// Full filter sheet for the dimensions that don't fit inline in the list
/// header (category, account, provider, amount range, month/year). Reads
/// and writes [transactionQueryProvider] directly, like the account list's
/// search/filter bar — no return value needed.
Future<void> showTransactionFilterSheet(
    BuildContext context, String userId, List<AccountModel> accounts) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _TransactionFilterSheet(userId: userId, accounts: accounts),
  );
}

class _TransactionFilterSheet extends ConsumerStatefulWidget {
  final String userId;
  final List<AccountModel> accounts;
  const _TransactionFilterSheet({required this.userId, required this.accounts});

  @override
  ConsumerState<_TransactionFilterSheet> createState() =>
      _TransactionFilterSheetState();
}

class _TransactionFilterSheetState
    extends ConsumerState<_TransactionFilterSheet> {
  late final TextEditingController _min;
  late final TextEditingController _max;

  @override
  void initState() {
    super.initState();
    final q = ref.read(transactionQueryProvider);
    _min = TextEditingController(text: q.minAmount?.toStringAsFixed(0) ?? '');
    _max = TextEditingController(text: q.maxAmount?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(transactionQueryProvider);
    final notifier = ref.read(transactionQueryProvider.notifier);
    final providers =
        ref.watch(transactionProviderOptionsProvider(widget.userId));
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text('Filters',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  if (query.hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        notifier.clearFilters();
                        setState(() {
                          _min.clear();
                          _max.clear();
                        });
                      },
                      child: const Text('Clear all'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _section('Category'),
              _chipWrap(
                options: TransactionFields.categories,
                selected: query.category,
                onSelected: notifier.setCategory,
              ),
              _section('Account'),
              _chipWrap(
                options: widget.accounts.map((a) => a.id).toList(),
                labelOf: (id) =>
                    widget.accounts.firstWhere((a) => a.id == id).accountName,
                selected: query.accountId,
                onSelected: notifier.setAccountId,
              ),
              if (providers.isNotEmpty) ...[
                _section('Provider'),
                _chipWrap(
                  options: providers,
                  selected: query.provider,
                  onSelected: notifier.setProvider,
                ),
              ],
              _section('Amount range (FCFA)'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Min', isDense: true),
                      onChanged: (v) => notifier.setAmountRange(
                          double.tryParse(v), query.maxAmount),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Max', isDense: true),
                      onChanged: (v) => notifier.setAmountRange(
                          query.minAmount, double.tryParse(v)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _section('Month'),
              _chipWrap(
                options: List.generate(12, (i) => (i + 1).toString()),
                labelOf: (m) => const [
                  'Jan',
                  'Feb',
                  'Mar',
                  'Apr',
                  'May',
                  'Jun',
                  'Jul',
                  'Aug',
                  'Sep',
                  'Oct',
                  'Nov',
                  'Dec'
                ][int.parse(m) - 1],
                selected: query.month?.toString(),
                onSelected: (v) =>
                    notifier.setMonth(v == null ? null : int.parse(v)),
              ),
              _section('Year'),
              _chipWrap(
                options: List.generate(5, (i) => (now.year - i).toString()),
                selected: query.year?.toString(),
                onSelected: (v) =>
                    notifier.setYear(v == null ? null : int.parse(v)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppTokens.brand),
                  child: const Text('Show results'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _chipWrap({
    required List<String> options,
    String Function(String)? labelOf,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(labelOf?.call(o) ?? o,
                style: const TextStyle(fontSize: 12)),
            selected: selected == o,
            onSelected: (v) => onSelected(v ? o : null),
            selectedColor: AppTokens.brand.withValues(alpha: 0.16),
            labelStyle: TextStyle(
                color: selected == o ? AppTokens.brand : null,
                fontWeight:
                    selected == o ? FontWeight.w600 : FontWeight.normal),
            side: BorderSide(
                color: selected == o
                    ? AppTokens.brand
                    : Theme.of(context).colorScheme.outlineVariant),
          ),
      ],
    );
  }
}
