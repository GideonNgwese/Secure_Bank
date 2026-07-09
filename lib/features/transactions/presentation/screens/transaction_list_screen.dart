import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/premium_header.dart';
import '../../../../models/account_model.dart';
import '../../../../models/transaction_model.dart';
import '../../../../screens/profile/profile_kyc_screen.dart';
import '../../../../screens/transactions/import_csv_screen.dart';
import '../../../../utils/constants.dart';
import '../../../accounts/data/account_providers.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../data/transaction_providers.dart';
import '../../domain/transaction_fields.dart';
import '../../domain/transaction_query.dart';
import '../../domain/transaction_view.dart';
import '../controllers/transaction_form_controller.dart';
import '../widgets/transaction_card.dart';
import '../widgets/transaction_empty_state.dart';
import '../widgets/transaction_filter_sheet.dart';
import '../widgets/transaction_skeleton.dart';
import 'transaction_detail_screen.dart';
import 'transaction_form_screen.dart';

/// Premium transactions list: real-time search, type chips, a full filter
/// sheet, sort menu, swipe-to-edit/delete, long-press actions, "load more"
/// pagination, and an animated empty state. This is the entry point wired
/// into the bottom-nav "Activity" tab.
class TransactionListScreen extends ConsumerStatefulWidget {
  final String userId;
  const TransactionListScreen({super.key, required this.userId});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  late final TextEditingController _search;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _search =
        TextEditingController(text: ref.read(transactionQueryProvider).search);
  }

  @override
  void dispose() {
    _search.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openAdd() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TransactionFormScreen(userId: widget.userId)));

  void _openEdit(TransactionModel tx) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              TransactionFormScreen(userId: widget.userId, existing: tx)));

  void _openDetail(TransactionModel tx) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(
              userId: widget.userId, transactionId: tx.id)));

  @override
  Widget build(BuildContext context) {
    final rawAsync = ref.watch(transactionsRawProvider(widget.userId));
    final rawLoaded = rawAsync.valueOrNull;
    final visibleAsync = ref.watch(visibleTransactionsProvider(widget.userId));
    final query = ref.watch(transactionQueryProvider);
    final notifier = ref.read(transactionQueryProvider.notifier);
    final accounts =
        ref.watch(accountsRawProvider(widget.userId)).valueOrNull ?? [];
    final hasMore = ref.watch(hasMoreTransactionsProvider(widget.userId));

    final trulyEmpty = rawLoaded != null && rawLoaded.isEmpty;

    final now = DateTime.now();
    final monthTx = (rawLoaded ?? const <TransactionModel>[]).where((t) =>
        t.isCompleted &&
        t.transactionDate.year == now.year &&
        t.transactionDate.month == now.month);
    final monthCount = monthTx.length;
    final monthNet = monthTx.fold<double>(0, (s, t) => s + t.signedAmount);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: AppTokens.brand,
        icon: const Icon(Icons.add),
        label: const Text('Add transaction'),
      ),
      body: Column(
        children: [
          PremiumHeader(
            userId: widget.userId,
            title: 'Transactions',
            scrollController: _scrollController,
            onAvatarTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfileKycScreen(userId: widget.userId))),
            onNotificationsTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        NotificationsScreen(userId: widget.userId))),
            onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(userId: widget.userId))),
            stats: rawLoaded == null
                ? null
                : [
                    HeaderStat('This month', '$monthCount transactions'),
                    HeaderStat('Net',
                        '${monthNet >= 0 ? '+' : ''}${formatFCFA(monthNet)}',
                        valueColor: monthNet >= 0
                            ? AppColors.success
                            : AppColors.danger),
                  ],
            extraActions: [
              HeaderIconButton(
                icon: Icons.upload_file_outlined,
                isDark: Theme.of(context).brightness == Brightness.dark,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ImportCsvScreen(userId: widget.userId))),
              ),
            ],
          ),
          Expanded(
            child: trulyEmpty
                ? TransactionEmptyState(onAdd: _openAdd)
                : RefreshIndicator(
                    onRefresh: () async {
                      ref.read(transactionPageSizeProvider.notifier).reset();
                      ref.invalidate(transactionsRawProvider(widget.userId));
                      ref.invalidate(accountsRawProvider(widget.userId));
                    },
                    child: rawLoaded == null
                        ? const TransactionSkeleton()
                        : CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                              SliverPadding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 10, 16, 4),
                                sliver: SliverToBoxAdapter(
                                  child: FadeSlideIn(
                                    offsetY: 12,
                                    child: _SearchAndFilters(
                                      controller: _search,
                                      userId: widget.userId,
                                      query: query,
                                      notifier: notifier,
                                      accounts: accounts,
                                    ),
                                  ),
                                ),
                              ),
                              visibleAsync.when(
                                loading: () => const SliverFillRemaining(
                                    child: Center(
                                        child: CircularProgressIndicator())),
                                error: (e, _) => SliverFillRemaining(
                                  child: _ErrorState(onRetry: () {
                                    ref.invalidate(
                                        transactionsRawProvider(widget.userId));
                                  }),
                                ),
                                data: (items) => items.isEmpty
                                    ? const SliverFillRemaining(
                                        hasScrollBody: false,
                                        child: TransactionNoMatchesState(),
                                      )
                                    : SliverList.separated(
                                        itemCount:
                                            items.length + (hasMore ? 1 : 0),
                                        separatorBuilder: (_, __) =>
                                            const SizedBox(height: 10),
                                        itemBuilder: (context, i) {
                                          if (i >= items.length) {
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                      horizontal: 16),
                                              child: Center(
                                                child: OutlinedButton(
                                                  onPressed: () => ref
                                                      .read(
                                                          transactionPageSizeProvider
                                                              .notifier)
                                                      .loadMore(),
                                                  child:
                                                      const Text('Load more'),
                                                ),
                                              ),
                                            );
                                          }
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            child: FadeSlideIn(
                                              duration: Duration(
                                                  milliseconds: 320 +
                                                      (i.clamp(0, 8) * 40)),
                                              child: _SwipeableTransactionTile(
                                                item: items[i],
                                                onTap: () => _openDetail(
                                                    items[i].transaction),
                                                onEdit: () => _openEdit(
                                                    items[i].transaction),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                              const SliverToBoxAdapter(
                                  child: SizedBox(height: 90)),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  final TextEditingController controller;
  final String userId;
  final TransactionQuery query;
  final TransactionQueryNotifier notifier;
  final List<AccountModel> accounts;

  const _SearchAndFilters({
    required this.controller,
    required this.userId,
    required this.query,
    required this.notifier,
    required this.accounts,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: notifier.setSearch,
                decoration: InputDecoration(
                  hintText: 'Search merchant, category, title…',
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
            _iconBadgeButton(
              context,
              icon: Icons.tune,
              badge: query.activeFilterCount,
              onTap: () =>
                  showTransactionFilterSheet(context, userId, accounts),
            ),
            const SizedBox(width: 6),
            PopupMenuButton<TransactionSort>(
              tooltip: 'Sort',
              onSelected: notifier.setSort,
              itemBuilder: (context) => [
                for (final s in TransactionSort.values)
                  PopupMenuItem(value: s, child: Text(s.label)),
              ],
              child: _iconBadgeButton(context, icon: Icons.swap_vert, badge: 0),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _typeChip(context, null, 'All'),
              for (final t in TransactionFields.types) _typeChip(context, t, t),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeChip(BuildContext context, String? value, String label) {
    final selected = query.type == value;
    final color =
        value == null ? AppTokens.brand : TransactionTypeStyle.colorOf(value);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => notifier.setType(value),
        selectedColor: color.withValues(alpha: 0.16),
        labelStyle: TextStyle(
            color: selected ? color : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
        side: BorderSide(
            color: selected
                ? color
                : Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }

  Widget _iconBadgeButton(BuildContext context,
      {required IconData icon, required int badge, VoidCallback? onTap}) {
    final scheme = Theme.of(context).colorScheme;
    final active = badge > 0;
    return Material(
      color: active
          ? AppTokens.brand.withValues(alpha: 0.14)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 20, color: active ? AppTokens.brand : null),
              if (badge > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: AppTokens.brand, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text('$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Swipe right → edit (snaps back), swipe left → delete (with confirmation).
class _SwipeableTransactionTile extends ConsumerWidget {
  final TransactionWithAccount item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const _SwipeableTransactionTile(
      {required this.item, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = item.transaction;
    final isTransfer = tx.type == 'Transfer';

    return Dismissible(
      key: ValueKey('tx-swipe-${tx.id}'),
      direction: isTransfer
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      background: _background(
          alignment: Alignment.centerLeft,
          color: AppTokens.brand,
          icon: Icons.edit_outlined,
          label: 'Edit'),
      secondaryBackground: _background(
          alignment: Alignment.centerRight,
          color: AppTokens.danger,
          icon: Icons.delete_outline,
          label: 'Delete'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false;
        }
        return _confirmDelete(context, ref, tx);
      },
      onDismissed: (_) =>
          ref.read(transactionFormControllerProvider.notifier).delete(tx),
      child: TransactionCard(
        item: item,
        onTap: onTap,
        onLongPress: () => _showActions(context, ref, tx, onEdit),
      ),
    );
  }

  Future<bool> _confirmDelete(
      BuildContext context, WidgetRef ref, TransactionModel tx) async {
    final isTransfer = tx.type == 'Transfer';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: Text(isTransfer
            ? 'This is a transfer. Both linked legs will be deleted. Balances update automatically.'
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
    return ok ?? false;
  }

  Widget _background(
      {required Alignment alignment,
      required Color color,
      required IconData icon,
      required String label}) {
    final leading = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(AppTokens.radius)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: leading
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ]
            : [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref, TransactionModel tx,
      VoidCallback onEdit) {
    final isTransfer = tx.type == 'Transfer';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4))),
            if (!isTransfer)
              ListTile(
                leading:
                    const Icon(Icons.edit_outlined, color: AppTokens.brand),
                title: const Text('Edit transaction'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onEdit();
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppTokens.danger),
              title: const Text('Delete transaction',
                  style: TextStyle(color: AppTokens.danger)),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                if (await _confirmDelete(context, ref, tx)) {
                  await ref
                      .read(transactionFormControllerProvider.notifier)
                      .delete(tx);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text("Couldn't load your transactions",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: AppTokens.brand),
            ),
          ],
        ),
      ),
    );
  }
}
