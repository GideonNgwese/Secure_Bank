enum BudgetSort { newest, nameAz, highestAmount, lowestAmount, mostUsed }

extension BudgetSortLabel on BudgetSort {
  String get label => switch (this) {
        BudgetSort.newest => 'Newest',
        BudgetSort.nameAz => 'Name (A-Z)',
        BudgetSort.highestAmount => 'Highest amount',
        BudgetSort.lowestAmount => 'Lowest amount',
        BudgetSort.mostUsed => '% used',
      };
}

/// Search / filter / sort state for the budget list. [status] covers both
/// persisted statuses (Active/Archived) and derived ones (Exceeded/
/// Completed) — see [BudgetWithProgress.displayStatus].
class BudgetQuery {
  final String search;
  final String? period;
  final String? category;
  final String? status;
  final BudgetSort sort;

  const BudgetQuery({
    this.search = '',
    this.period,
    this.category,
    this.status,
    this.sort = BudgetSort.newest,
  });

  BudgetQuery copyWith({
    String? search,
    String? Function()? period,
    String? Function()? category,
    String? Function()? status,
    BudgetSort? sort,
  }) =>
      BudgetQuery(
        search: search ?? this.search,
        period: period != null ? period() : this.period,
        category: category != null ? category() : this.category,
        status: status != null ? status() : this.status,
        sort: sort ?? this.sort,
      );

  bool get hasActiveFilters =>
      period != null || category != null || status != null;

  int get activeFilterCount =>
      [period, category, status].where((f) => f != null).length;

  BudgetQuery clearFilters() => BudgetQuery(search: search, sort: sort);
}
