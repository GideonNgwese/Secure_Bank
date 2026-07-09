import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../utils/constants.dart';
import '../../data/account_providers.dart';
import '../../domain/account_view.dart';

/// Search box + type chips + provider/sort/archived controls for the
/// accounts list. Reads/writes [accountQueryProvider] directly so the list
/// screen just needs to watch the derived, already-filtered results.
class AccountSearchFilterBar extends ConsumerStatefulWidget {
  final List<String> availableProviders;
  const AccountSearchFilterBar({super.key, required this.availableProviders});

  @override
  ConsumerState<AccountSearchFilterBar> createState() =>
      _AccountSearchFilterBarState();
}

class _AccountSearchFilterBarState
    extends ConsumerState<AccountSearchFilterBar> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search =
        TextEditingController(text: ref.read(accountQueryProvider).search);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(accountQueryProvider);
    final notifier = ref.read(accountQueryProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: notifier.setSearch,
          decoration: InputDecoration(
            hintText: 'Search accounts, provider, number…',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: query.search.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _search.clear();
                      notifier.setSearch('');
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _typeChip(context, null, 'All', query, notifier),
              for (final t in kAccountTypes)
                _typeChip(context, t, t, query, notifier),
              const SizedBox(width: 4),
              Container(
                  width: 1,
                  color: Colors.black12,
                  margin: const EdgeInsets.symmetric(vertical: 4)),
              const SizedBox(width: 8),
              _providerMenu(context, query, notifier),
              const SizedBox(width: 8),
              _sortMenu(context, query, notifier),
              const SizedBox(width: 8),
              _archivedToggle(context, query, notifier),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeChip(BuildContext context, String? value, String label,
      AccountQuery query, AccountQueryNotifier notifier) {
    final selected = query.type == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => notifier.setType(value),
        selectedColor: AppColors.primary.withValues(alpha: 0.16),
        labelStyle: TextStyle(
            color: selected ? AppColors.primary : Colors.black87,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
        backgroundColor: Colors.white,
        side: BorderSide(color: selected ? AppColors.primary : Colors.black12),
      ),
    );
  }

  Widget _providerMenu(
      BuildContext context, AccountQuery query, AccountQueryNotifier notifier) {
    return PopupMenuButton<String?>(
      tooltip: 'Filter by provider',
      onSelected: notifier.setProvider,
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All providers')),
        for (final p in widget.availableProviders)
          PopupMenuItem(value: p, child: Text(p)),
      ],
      child: _pillButton(
        icon: Icons.business_outlined,
        label: query.provider ?? 'Provider',
        active: query.provider != null,
      ),
    );
  }

  Widget _sortMenu(
      BuildContext context, AccountQuery query, AccountQueryNotifier notifier) {
    return PopupMenuButton<AccountSort>(
      tooltip: 'Sort',
      onSelected: notifier.setSort,
      itemBuilder: (context) => [
        for (final s in AccountSort.values)
          PopupMenuItem(value: s, child: Text(s.label)),
      ],
      child: _pillButton(
        icon: Icons.swap_vert,
        label: query.sort.label,
        active: query.sort != AccountSort.newest,
      ),
    );
  }

  Widget _archivedToggle(
      BuildContext context, AccountQuery query, AccountQueryNotifier notifier) {
    return GestureDetector(
      onTap: () => notifier.setShowArchived(!query.showArchived),
      child: _pillButton(
        icon: query.showArchived ? Icons.archive : Icons.archive_outlined,
        label: 'Archived',
        active: query.showArchived,
      ),
    );
  }

  Widget _pillButton(
      {required IconData icon, required String label, required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:
            active ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.primary : Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 15, color: active ? AppColors.primary : Colors.black54),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: active ? AppColors.primary : Colors.black87,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
          ),
        ],
      ),
    );
  }
}
