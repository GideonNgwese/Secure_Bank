import 'transaction_model.dart';

/// A user-defined spending budget for one category over a date range.
///
/// Deliberately does NOT store `spentAmount`/`remainingAmount` — those are
/// always computed live from the user's transactions (see
/// `features/budget/domain/budget_view.dart`'s `BudgetWithProgress`), the
/// same pattern already used for account balances. A stored running total
/// would need every transaction write to remember to increment/decrement it
/// correctly (including on edit and delete) with no Cloud Functions to
/// enforce that — a live sum over the same `transactions` collection is
/// simpler, always consistent, and just as "automatic".
class BudgetModel {
  final String id;
  final String userId;
  final String name;
  final String category;
  final double budgetAmount;
  final String currency; // FCFA default
  final String period; // Daily / Weekly / Monthly / Quarterly / Yearly / Custom
  final DateTime startDate;
  final DateTime endDate;
  final String status; // Active / Archived
  final int color; // ARGB
  final String icon; // key into BudgetFields.icons
  final String notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const BudgetModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.budgetAmount,
    this.currency = 'FCFA',
    required this.period,
    required this.startDate,
    required this.endDate,
    this.status = 'Active',
    required this.color,
    required this.icon,
    this.notes = '',
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'Active';
  bool get isArchived => status == 'Archived';

  /// Completed expense transactions in this category, within this budget's
  /// date range — the one formula every "how much of this budget is spent"
  /// call site shares (live-computed, per the no-stored-spentAmount design
  /// above) instead of each re-implementing the same filter independently.
  double spentFrom(List<TransactionModel> allTx) => allTx
      .where((t) =>
          t.type == 'Expense' &&
          t.isCompleted &&
          t.category == category &&
          !t.transactionDate.isBefore(startDate) &&
          !t.transactionDate.isAfter(endDate))
      .fold<double>(0, (s, t) => s + t.amount);

  factory BudgetModel.fromMap(String id, Map<String, dynamic> map) {
    final now = DateTime.now();
    return BudgetModel(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? (map['category'] ?? 'Budget'),
      category: map['category'] ?? 'Other',
      // tolerate the legacy `limitAmount` field name from before this redesign
      budgetAmount:
          ((map['budgetAmount'] ?? map['limitAmount']) ?? 0).toDouble(),
      currency: map['currency'] ?? 'FCFA',
      period: map['period'] ?? 'Monthly',
      startDate:
          DateTime.tryParse(map['startDate'] ?? '') ?? _legacyStart(map, now),
      endDate: DateTime.tryParse(map['endDate'] ?? '') ?? _legacyEnd(map, now),
      status: map['status'] ?? 'Active',
      color: map['color'] ?? 0xFF3E74FF,
      icon: map['icon'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? now,
      updatedAt:
          map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
    );
  }

  /// Legacy docs (pre-redesign) stored `month`/`year` instead of a date
  /// range — reconstruct the equivalent calendar-month range so old budgets
  /// keep working without a manual migration.
  static DateTime _legacyStart(Map<String, dynamic> map, DateTime now) {
    final month = map['month'] ?? now.month;
    final year = map['year'] ?? now.year;
    return DateTime(year, month, 1);
  }

  static DateTime _legacyEnd(Map<String, dynamic> map, DateTime now) {
    final month = map['month'] ?? now.month;
    final year = map['year'] ?? now.year;
    return DateTime(year, month + 1, 0, 23, 59, 59);
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'category': category,
      'budgetAmount': budgetAmount,
      'currency': currency,
      'period': period,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status,
      'color': color,
      'icon': icon,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  BudgetModel copyWith({
    String? name,
    String? category,
    double? budgetAmount,
    String? currency,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int? color,
    String? icon,
    String? notes,
    DateTime? updatedAt,
  }) =>
      BudgetModel(
        id: id,
        userId: userId,
        name: name ?? this.name,
        category: category ?? this.category,
        budgetAmount: budgetAmount ?? this.budgetAmount,
        currency: currency ?? this.currency,
        period: period ?? this.period,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        status: status ?? this.status,
        color: color ?? this.color,
        icon: icon ?? this.icon,
        notes: notes ?? this.notes,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
