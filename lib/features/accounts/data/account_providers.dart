import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/account_model.dart';
import '../../../models/transaction_model.dart';
import '../../../services/firestore_service.dart';
import '../domain/account_view.dart';
import 'account_repository.dart';

final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => AccountRepository(FirestoreService()));

final accountsRawProvider = StreamProvider.family<List<AccountModel>, String>(
    (ref, userId) =>
        ref.watch(accountRepositoryProvider).watchAccounts(userId));

final accountsTxProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, userId) =>
        ref.watch(accountRepositoryProvider).watchTransactions(userId));

/// Search / filter / sort state.
class AccountQueryNotifier extends Notifier<AccountQuery> {
  @override
  AccountQuery build() => const AccountQuery();

  void setSearch(String s) => state = state.copyWith(search: s);
  void setType(String? t) => state = state.copyWith(type: () => t);
  void setProvider(String? p) => state = state.copyWith(provider: () => p);
  void setSort(AccountSort s) => state = state.copyWith(sort: s);
  void setShowArchived(bool v) => state = state.copyWith(showArchived: v);
  void clear() => state = const AccountQuery();
}

final accountQueryProvider =
    NotifierProvider<AccountQueryNotifier, AccountQuery>(
        AccountQueryNotifier.new);

/// The list after balances, filtering and sorting are applied.
final visibleAccountsProvider =
    Provider.family<AsyncValue<List<AccountWithBalance>>, String>(
        (ref, userId) {
  final accountsAsync = ref.watch(accountsRawProvider(userId));
  final txsAsync = ref.watch(accountsTxProvider(userId));
  final query = ref.watch(accountQueryProvider);
  final repo = ref.watch(accountRepositoryProvider);

  return accountsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (accounts) => txsAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
      data: (txs) {
        var list = accounts
            .map((a) => AccountWithBalance(a, repo.balanceOf(a, txs)))
            .toList();

        if (!query.showArchived) {
          list = list.where((x) => !x.account.isArchived).toList();
        }
        final q = query.search.trim().toLowerCase();
        if (q.isNotEmpty) {
          list = list
              .where((x) =>
                  x.account.accountName.toLowerCase().contains(q) ||
                  x.account.provider.toLowerCase().contains(q) ||
                  x.account.maskedNumber.toLowerCase().contains(q))
              .toList();
        }
        if (query.type != null) {
          list =
              list.where((x) => x.account.accountType == query.type).toList();
        }
        if (query.provider != null) {
          list =
              list.where((x) => x.account.provider == query.provider).toList();
        }
        switch (query.sort) {
          case AccountSort.newest:
            list.sort(
                (a, b) => b.account.createdAt.compareTo(a.account.createdAt));
          case AccountSort.balanceHigh:
            list.sort((a, b) => b.balance.compareTo(a.balance));
          case AccountSort.balanceLow:
            list.sort((a, b) => a.balance.compareTo(b.balance));
          case AccountSort.name:
            list.sort((a, b) => a.account.accountName
                .toLowerCase()
                .compareTo(b.account.accountName.toLowerCase()));
        }
        return AsyncValue.data(list);
      },
    ),
  );
});

/// Total balance across active accounts (for the header card).
final accountsTotalProvider = Provider.family<double, String>((ref, userId) {
  final accounts = ref.watch(accountsRawProvider(userId)).valueOrNull ?? [];
  final txs = ref.watch(accountsTxProvider(userId)).valueOrNull ?? [];
  final repo = ref.watch(accountRepositoryProvider);
  return accounts
      .where((a) => a.isActive)
      .fold<double>(0, (s, a) => s + repo.balanceOf(a, txs));
});
