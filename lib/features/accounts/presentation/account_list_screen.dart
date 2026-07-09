import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/premium_header.dart';
import '../../../models/account_model.dart';
import '../../../screens/profile/profile_kyc_screen.dart';
import '../../../utils/constants.dart';
import '../../notifications/presentation/screens/notifications_screen.dart';
import '../../settings/presentation/screens/settings_screen.dart';
import '../data/account_providers.dart';
import '../domain/account_view.dart';
import 'account_detail_screen.dart';
import 'account_form_screen.dart';
import 'widgets/account_card.dart';
import 'widgets/account_empty_state.dart';
import 'widgets/account_search_filter_bar.dart';
import 'widgets/account_summary_header.dart';

/// Premium account management screen: search/filter/sort, a responsive
/// grid/list of gradient account cards, swipe actions, and a create flow.
/// This is the entry point wired into the bottom-nav "Accounts" tab.
class AccountListScreen extends ConsumerStatefulWidget {
  final String userId;
  const AccountListScreen({super.key, required this.userId});

  @override
  ConsumerState<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends ConsumerState<AccountListScreen> {
  bool _hideBalance = false;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openAdd() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountFormScreen(userId: widget.userId)));

  void _openEdit(AccountModel a) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              AccountFormScreen(userId: widget.userId, existing: a)));

  void _openDetail(AccountModel a) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              AccountDetailScreen(userId: widget.userId, accountId: a.id)));

  @override
  Widget build(BuildContext context) {
    final rawAccounts =
        ref.watch(accountsRawProvider(widget.userId)).valueOrNull ?? [];
    final visibleAsync = ref.watch(visibleAccountsProvider(widget.userId));
    final total = ref.watch(accountsTotalProvider(widget.userId));
    final providers = rawAccounts.map((a) => a.provider).toSet().toList()
      ..sort();

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add account'),
      ),
      body: Column(
        children: [
          PremiumHeader(
            userId: widget.userId,
            title: 'Accounts',
            scrollController: _scrollController,
            onAvatarTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfileKycScreen(userId: widget.userId))),
            onNotificationsTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) =>
                        NotificationsScreen(userId: widget.userId))),
            onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(userId: widget.userId))),
            stats: [HeaderStat('Total balance', formatFCFA(total))],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: rawAccounts.isEmpty &&
                      !ref.watch(accountsRawProvider(widget.userId)).isLoading
                  ? AccountEmptyState(onAddAccount: _openAdd)
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(accountsRawProvider(widget.userId));
                        ref.invalidate(accountsTxProvider(widget.userId));
                      },
                      child: CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FadeSlideIn(
                                    offsetY: 12,
                                    child: AccountSummaryHeader(
                                      total: total,
                                      accountCount: rawAccounts
                                          .where((a) => a.isActive)
                                          .length,
                                      hidden: _hideBalance,
                                      onToggleHidden: () => setState(
                                          () => _hideBalance = !_hideBalance),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  AccountSearchFilterBar(
                                      availableProviders: providers),
                                ],
                              ),
                            ),
                          ),
                          visibleAsync.when(
                            loading: () => const SliverFillRemaining(
                                child:
                                    Center(child: CircularProgressIndicator())),
                            error: (e, _) => SliverFillRemaining(
                              child: _ErrorState(onRetry: () {
                                ref.invalidate(
                                    accountsRawProvider(widget.userId));
                                ref.invalidate(
                                    accountsTxProvider(widget.userId));
                              }),
                            ),
                            data: (items) => items.isEmpty
                                ? const SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: _NoMatchesState(),
                                  )
                                : SliverPadding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 100),
                                    sliver: context.isTablet
                                        ? _grid(items)
                                        : _list(items),
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(List<AccountWithBalance> items) {
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => FadeSlideIn(
        duration: Duration(milliseconds: 380 + (i.clamp(0, 8) * 45)),
        child: _SwipeableAccountTile(
          item: items[i],
          onTap: () => _openDetail(items[i].account),
          onEdit: () => _openEdit(items[i].account),
        ),
      ),
    );
  }

  Widget _grid(List<AccountWithBalance> items) {
    final cols = context.isDesktop ? 3 : 2;
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.5,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) => FadeSlideIn(
          duration: Duration(milliseconds: 380 + (i.clamp(0, 8) * 45)),
          child: _AccountTileActions(
            item: items[i],
            onTap: () => _openDetail(items[i].account),
            onEdit: () => _openEdit(items[i].account),
          ),
        ),
        childCount: items.length,
      ),
    );
  }
}

/// Wraps [AccountCard] with a small overflow button (always available — the
/// only affordance on tablet/desktop, a supplement to swipe on phones) plus
/// tap/long-press.
class _AccountTileActions extends ConsumerWidget {
  final AccountWithBalance item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const _AccountTileActions(
      {required this.item, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        AccountCard(
          item: item,
          onTap: onTap,
          onLongPress: () =>
              showAccountActionsSheet(context, ref, item.account, onEdit),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.white.withValues(alpha: 0.18),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () =>
                  showAccountActionsSheet(context, ref, item.account, onEdit),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.more_horiz, color: Colors.white, size: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Phone-list version: same as [_AccountTileActions] but also swipeable —
/// swipe right to edit, swipe left to archive/restore.
class _SwipeableAccountTile extends ConsumerWidget {
  final AccountWithBalance item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  const _SwipeableAccountTile(
      {required this.item, required this.onTap, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = item.account;
    final repo = ref.read(accountRepositoryProvider);

    return Dismissible(
      key: ValueKey('account-swipe-${a.id}'),
      direction: DismissDirection.horizontal,
      background: _swipeBackground(
        alignment: Alignment.centerLeft,
        color: AppColors.primary,
        icon: Icons.edit_outlined,
        label: 'Edit',
      ),
      secondaryBackground: _swipeBackground(
        alignment: Alignment.centerRight,
        color: a.isArchived ? AppColors.success : AppColors.warning,
        icon: a.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
        label: a.isArchived ? 'Restore' : 'Archive',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
          return false; // never actually dismiss for edit — just snap back
        }
        final newStatus = a.isArchived ? 'Active' : 'Archived';
        await repo.setStatus(a, newStatus);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(newStatus == 'Archived'
                ? '${a.accountName} archived'
                : '${a.accountName} restored'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => repo.setStatus(a, a.status),
            ),
          ));
        }
        return true;
      },
      child: _AccountTileActions(item: item, onTap: onTap, onEdit: onEdit),
    );
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    final leading = alignment == Alignment.centerLeft;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
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
}

/// Long-press / overflow action sheet shared by list and grid layouts.
void showAccountActionsSheet(
    BuildContext context, WidgetRef ref, AccountModel a, VoidCallback onEdit) {
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
                color: Colors.black12, borderRadius: BorderRadius.circular(4)),
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
            title: const Text('Edit account'),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onEdit();
            },
          ),
          ListTile(
            leading: Icon(
                a.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                color: AppColors.warning),
            title: Text(a.isArchived ? 'Restore account' : 'Archive account'),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await ref
                  .read(accountRepositoryProvider)
                  .setStatus(a, a.isArchived ? 'Active' : 'Archived');
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: const Text('Delete account',
                style: TextStyle(color: AppColors.danger)),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete this account?'),
                  content: Text(
                      'This removes "${a.accountName}". Its transactions stay '
                      'but will no longer show a linked account.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(accountRepositoryProvider).delete(a.id);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _NoMatchesState extends StatelessWidget {
  const _NoMatchesState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No accounts match your search or filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text("Couldn't load your accounts",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
