import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/account_model.dart';
import '../../../models/transaction_model.dart';
import '../../../services/firestore_service.dart';
import '../../accounts/data/account_providers.dart' show accountsRawProvider;
import '../domain/transaction_query.dart';
import '../domain/transaction_view.dart';
import 'transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
    (ref) => TransactionRepository(FirestoreService()));

const _pageSize = 60;
const _maxPageSize = 1000;

/// How many of the most recent transactions to keep live-subscribed to.
/// "Load more" bumps this, which re-subscribes [transactionsRawProvider]
/// with a larger limit — see that provider for why this is simpler (and
/// safer) than cursor-based pagination on top of a live stream.
class TransactionPageSizeNotifier extends Notifier<int> {
  @override
  int build() => _pageSize;

  void loadMore() {
    if (state < _maxPageSize)
      state = (state + _pageSize).clamp(0, _maxPageSize);
  }

  void reset() => state = _pageSize;
}

final transactionPageSizeProvider =
    NotifierProvider<TransactionPageSizeNotifier, int>(
        TransactionPageSizeNotifier.new);

/// Live, bounded transaction stream for a user. Re-subscribes whenever
/// [transactionPageSizeProvider] grows.
final transactionsRawProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, userId) {
  final limit = ref.watch(transactionPageSizeProvider);
  return ref.watch(transactionRepositoryProvider).watch(userId, limit: limit);
});

/// Live single transaction by id — the Fraud Review Screen's data source
/// (independent of the paginated list's current page size).
final transactionByIdProvider =
    StreamProvider.family<TransactionModel?, String>((ref, id) =>
        ref.watch(transactionRepositoryProvider).watchById(id));

/// Whether there may be more, older transactions beyond the current page —
/// a full page suggests Firestore had more to give than the limit allowed.
final hasMoreTransactionsProvider =
    Provider.family<bool, String>((ref, userId) {
  final count =
      ref.watch(transactionsRawProvider(userId)).valueOrNull?.length ?? 0;
  return count > 0 && count >= ref.watch(transactionPageSizeProvider);
});

/// Search / filter / sort state.
class TransactionQueryNotifier extends Notifier<TransactionQuery> {
  @override
  TransactionQuery build() => const TransactionQuery();

  void setSearch(String s) => state = state.copyWith(search: s);
  void setType(String? t) => state = state.copyWith(type: () => t);
  void setCategory(String? c) => state = state.copyWith(category: () => c);
  void setAccountId(String? a) => state = state.copyWith(accountId: () => a);
  void setProvider(String? p) => state = state.copyWith(provider: () => p);
  void setAmountRange(double? min, double? max) =>
      state = state.copyWith(minAmount: () => min, maxAmount: () => max);
  void setMonth(int? m) => state = state.copyWith(month: () => m);
  void setYear(int? y) => state = state.copyWith(year: () => y);
  void setSort(TransactionSort s) => state = state.copyWith(sort: s);
  void clearFilters() => state = state.clearFilters();
}

final transactionQueryProvider =
    NotifierProvider<TransactionQueryNotifier, TransactionQuery>(
        TransactionQueryNotifier.new);

/// The list after search, every filter, and sort are applied, each paired
/// with its resolved account.
final visibleTransactionsProvider =
    Provider.family<AsyncValue<List<TransactionWithAccount>>, String>(
        (ref, userId) {
  final txAsync = ref.watch(transactionsRawProvider(userId));
  final accAsync = ref.watch(accountsRawProvider(userId));
  final query = ref.watch(transactionQueryProvider);

  return txAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
    data: (txs) => accAsync.when(
      loading: () => const AsyncValue.loading(),
      error: (e, st) => AsyncValue.error(e, st),
      data: (accounts) {
        final byId = {for (final a in accounts) a.id: a};
        var list = txs
            .map((t) => TransactionWithAccount(t, byId[t.accountId]))
            .toList();

        final q = query.search.trim().toLowerCase();
        if (q.isNotEmpty) {
          list = list.where((x) {
            final t = x.transaction;
            return t.merchant.toLowerCase().contains(q) ||
                t.category.toLowerCase().contains(q) ||
                t.title.toLowerCase().contains(q) ||
                t.description.toLowerCase().contains(q);
          }).toList();
        }
        if (query.type != null) {
          list = list.where((x) => x.transaction.type == query.type).toList();
        }
        if (query.category != null) {
          list = list
              .where((x) => x.transaction.category == query.category)
              .toList();
        }
        if (query.accountId != null) {
          list = list
              .where((x) => x.transaction.accountId == query.accountId)
              .toList();
        }
        if (query.provider != null) {
          list =
              list.where((x) => x.account?.provider == query.provider).toList();
        }
        if (query.minAmount != null) {
          list = list
              .where((x) => x.transaction.amount >= query.minAmount!)
              .toList();
        }
        if (query.maxAmount != null) {
          list = list
              .where((x) => x.transaction.amount <= query.maxAmount!)
              .toList();
        }
        if (query.month != null) {
          list = list
              .where((x) => x.transaction.transactionDate.month == query.month)
              .toList();
        }
        if (query.year != null) {
          list = list
              .where((x) => x.transaction.transactionDate.year == query.year)
              .toList();
        }
        switch (query.sort) {
          case TransactionSort.newest:
            list.sort((a, b) => b.transaction.transactionDate
                .compareTo(a.transaction.transactionDate));
          case TransactionSort.oldest:
            list.sort((a, b) => a.transaction.transactionDate
                .compareTo(b.transaction.transactionDate));
          case TransactionSort.highestAmount:
            list.sort(
                (a, b) => b.transaction.amount.compareTo(a.transaction.amount));
          case TransactionSort.lowestAmount:
            list.sort(
                (a, b) => a.transaction.amount.compareTo(b.transaction.amount));
          case TransactionSort.category:
            list.sort((a, b) =>
                a.transaction.category.compareTo(b.transaction.category));
          case TransactionSort.alphabetical:
            list.sort((a, b) => _displayTitle(a.transaction)
                .toLowerCase()
                .compareTo(_displayTitle(b.transaction).toLowerCase()));
        }
        return AsyncValue.data(list);
      },
    ),
  );
});

String _displayTitle(TransactionModel t) => t.title.isNotEmpty
    ? t.title
    : (t.description.isNotEmpty ? t.description : t.category);

/// Distinct account providers among the user's own accounts, for the
/// provider filter.
final transactionProviderOptionsProvider =
    Provider.family<List<String>, String>((ref, userId) {
  final accounts = ref.watch(accountsRawProvider(userId)).valueOrNull ?? [];
  final set = accounts.map((AccountModel a) => a.provider).toSet().toList()
    ..sort();
  return set;
});
