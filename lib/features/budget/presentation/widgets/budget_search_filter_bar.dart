import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/budget_providers.dart';
import '../../domain/budget_fields.dart';
import '../../domain/budget_query.dart';

/// Search box + period chips + status chips + category/sort menus for the
/// budget list. Reads/writes [budgetQueryProvider] directly, mirroring the
/// Accounts/Transactions search-and-filter bars.
class BudgetSearchFilterBar extends ConsumerStatefulWidget {
  final String userId;
  const BudgetSearchFilterBar({super.key, required this.userId});

  @override
  ConsumerState<BudgetSearchFilterBar> createState() =>
      _BudgetSearchFilterBarState();
}

class _BudgetSearchFilterBarState extends ConsumerState<BudgetSearchFilterBar> {
  late final TextEditingController _search;

  static const _statuses = ['Active', 'Archived', 'Exceeded', 'Completed'];

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(budgetQueryProvider).search);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(budgetQueryProvider);
    final notifier = ref.read(budgetQueryProvider.notifier);
    final categories = ref.watch(budgetCategoryOptionsProvider(widget.userId));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: notifier.setSearch,
                decoration: InputDecoration(
                  hintText: 'Search budgets, category, period…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String?>(
              tooltip: 'Filter by category',
              onSelected: notifier.setCategory,
              itemBuilder: (context) => [
                const PopupMenuItem(value: null, child: Text('All categories')),
                for (final c in categories)
                  PopupMenuItem(value: c, child: Text(c)),
              ],
              child: _pill(context, Icons.category_outlined,
                  query.category ?? 'Category', query.category != null),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<BudgetSort>(
              tooltip: 'Sort',
              onSelected: notifier.setSort,
              itemBuilder: (context) => [
                for (final s in BudgetSort.values)
                  PopupMenuItem(value: s, child: Text(s.label)),
              ],
              child: _pill(context, Icons.swap_vert, query.sort.label,
                  query.sort != BudgetSort.newest),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip(context, 'All periods', query.period == null,
                  () => notifier.setPeriod(null)),
              for (final p in BudgetFields.periods)
                _chip(
                    context, p, query.period == p, () => notifier.setPeriod(p)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _chip(context, 'All statuses', query.status == null,
                  () => notifier.setStatus(null)),
              for (final s in _statuses)
                _chip(
                    context, s, query.status == s, () => notifier.setStatus(s)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTokens.brand.withValues(alpha: 0.16),
        labelStyle: TextStyle(
            color: selected ? AppTokens.brand : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
        side: BorderSide(
            color: selected
                ? AppTokens.brand
                : Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label, bool active) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? AppTokens.brand.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: active ? AppTokens.brand : Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 15,
              color: active ? AppTokens.brand : scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? AppTokens.brand : scheme.onSurface,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ),
        ],
      ),
    );
  }
}
