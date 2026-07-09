enum TransactionSort {
  newest,
  oldest,
  highestAmount,
  lowestAmount,
  category,
  alphabetical,
}

extension TransactionSortLabel on TransactionSort {
  String get label => switch (this) {
        TransactionSort.newest => 'Newest',
        TransactionSort.oldest => 'Oldest',
        TransactionSort.highestAmount => 'Highest amount',
        TransactionSort.lowestAmount => 'Lowest amount',
        TransactionSort.category => 'Category',
        TransactionSort.alphabetical => 'Alphabetical',
      };
}

/// Search / filter / sort state for the transactions list. Filtering and
/// sorting themselves happen client-side over the live Firestore stream (see
/// `transaction_providers.dart`) — Firestore alone can't do free-text search
/// or this many simultaneous filter dimensions efficiently.
class TransactionQuery {
  final String search;
  final String? type;
  final String? category;
  final String? accountId;
  final String? provider; // the linked account's provider (e.g. MTN MoMo)
  final double? minAmount;
  final double? maxAmount;
  final int? month; // 1-12, null = any
  final int? year;
  final TransactionSort sort;

  const TransactionQuery({
    this.search = '',
    this.type,
    this.category,
    this.accountId,
    this.provider,
    this.minAmount,
    this.maxAmount,
    this.month,
    this.year,
    this.sort = TransactionSort.newest,
  });

  TransactionQuery copyWith({
    String? search,
    String? Function()? type,
    String? Function()? category,
    String? Function()? accountId,
    String? Function()? provider,
    double? Function()? minAmount,
    double? Function()? maxAmount,
    int? Function()? month,
    int? Function()? year,
    TransactionSort? sort,
  }) =>
      TransactionQuery(
        search: search ?? this.search,
        type: type != null ? type() : this.type,
        category: category != null ? category() : this.category,
        accountId: accountId != null ? accountId() : this.accountId,
        provider: provider != null ? provider() : this.provider,
        minAmount: minAmount != null ? minAmount() : this.minAmount,
        maxAmount: maxAmount != null ? maxAmount() : this.maxAmount,
        month: month != null ? month() : this.month,
        year: year != null ? year() : this.year,
        sort: sort ?? this.sort,
      );

  bool get hasActiveFilters =>
      type != null ||
      category != null ||
      accountId != null ||
      provider != null ||
      minAmount != null ||
      maxAmount != null ||
      month != null ||
      year != null;

  int get activeFilterCount => [
        type,
        category,
        accountId,
        provider,
        minAmount,
        maxAmount,
        month,
        year,
      ].where((f) => f != null).length;

  /// Resets every filter but keeps the current search text — clearing
  /// filters shouldn't also clear what the user is searching for.
  TransactionQuery clearFilters() =>
      TransactionQuery(search: search, sort: sort);
}
