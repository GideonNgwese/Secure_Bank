import '../../../models/budget_model.dart';

class BudgetValidators {
  BudgetValidators._();

  static String? name(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Budget name is required';
    if (s.length < 3) return 'Enter at least 3 characters';
    return null;
  }

  static String? amount(String? v) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a valid amount';
    if (n <= 0) return 'Budget amount must be greater than 0';
    return null;
  }

  static String? dateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'Select a start and end date';
    if (start.isAfter(end)) return 'Start date cannot be after end date';
    return null;
  }

  /// True if an active budget already exists for the same category with an
  /// overlapping date range — the spec's "no duplicate active budget for the
  /// same category and period unless explicitly allowed". [excludeId] should
  /// be the budget's own id when editing.
  static bool hasOverlappingActiveBudget({
    required List<BudgetModel> existing,
    required String category,
    required DateTime start,
    required DateTime end,
    String? excludeId,
  }) {
    return existing.any((b) =>
        b.id != excludeId &&
        b.isActive &&
        b.category == category &&
        start.isBefore(b.endDate) &&
        end.isAfter(b.startDate));
  }
}
