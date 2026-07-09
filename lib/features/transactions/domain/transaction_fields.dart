import 'package:flutter/material.dart';

import '../../../models/transaction_model.dart';
import '../../../utils/constants.dart';

/// Curated option lists + type/category styling for the Transactions
/// feature. Kept as simple constants + pure functions (mirrors the pattern
/// used for account providers/types) so new options don't touch any widget.
class TransactionFields {
  TransactionFields._();

  static const List<String> types = [
    'Income',
    'Expense',
    'Transfer',
    'Refund',
    'Adjustment',
  ];

  /// Base categories, shared with Budgets. Users can add their own on top —
  /// see [CategoryOptions].
  static const List<String> categories = kCategories;

  static const List<String> paymentMethods = [
    'Cash',
    'Mobile Money',
    'Bank Transfer',
    'Card',
    'Cheque',
    'Other',
  ];

  static const List<String> statuses = kTransactionStatuses;

  static const List<String> currencies = ['FCFA', 'USD', 'EUR', 'GBP'];
}

/// Per-type color coding, per the design spec: Income green, Expense red,
/// Transfer blue, Refund purple, Adjustment slate (not specified — a neutral
/// "correction" tone distinct from the other four).
class TransactionTypeStyle {
  TransactionTypeStyle._();

  static const _income = Color(0xFF1FA96A);
  static const _expense = Color(0xFFE84C4C);
  static const _transfer = Color(0xFF2E5BFF);
  static const _refund = Color(0xFF9B37E0);
  static const _adjustment = Color(0xFF6B7280);

  static Color colorOf(String type) => switch (type) {
        'Income' => _income,
        'Expense' => _expense,
        'Transfer' => _transfer,
        'Refund' => _refund,
        'Adjustment' => _adjustment,
        _ => _expense,
      };

  static IconData iconOf(String type) => switch (type) {
        'Income' => Icons.south_west_rounded,
        'Expense' => Icons.north_east_rounded,
        'Transfer' => Icons.swap_horiz_rounded,
        'Refund' => Icons.replay_rounded,
        'Adjustment' => Icons.tune_rounded,
        _ => Icons.receipt_long_outlined,
      };

  /// Whether this type generally credits (+) an account, for sign display.
  /// Adjustment has no fixed direction — callers should use the actual
  /// signed amount instead of this for that type.
  static bool isCredit(String type) => type == 'Income' || type == 'Refund';
}

/// Category → icon, independent of type (a "Food" expense and a rare "Food"
/// refund both show the same fork/knife icon).
class TransactionCategoryStyle {
  TransactionCategoryStyle._();

  static IconData iconOf(String category) => switch (category) {
        'Salary' => Icons.payments_outlined,
        'Business' => Icons.storefront_outlined,
        'Food' => Icons.restaurant_outlined,
        'Transport' => Icons.directions_bus_outlined,
        'Shopping' => Icons.shopping_bag_outlined,
        'Bills' => Icons.receipt_outlined,
        'Entertainment' => Icons.movie_outlined,
        'Healthcare' => Icons.local_hospital_outlined,
        'Education' => Icons.school_outlined,
        'Savings' => Icons.savings_outlined,
        'Investment' => Icons.trending_up_rounded,
        'Utilities' => Icons.bolt_outlined,
        'Travel' => Icons.flight_takeoff_outlined,
        'Gift' => Icons.card_giftcard_outlined,
        'Rent' => Icons.home_outlined,
        'Insurance' => Icons.shield_outlined,
        'Taxes' => Icons.account_balance_outlined,
        'Loan' => Icons.request_quote_outlined,
        'Mobile Money' => Icons.smartphone_outlined,
        'Cash' => Icons.payments_outlined,
        'Transfer In' || 'Transfer Out' => Icons.swap_horiz_rounded,
        'Others' || 'Other' => Icons.category_outlined,
        _ => Icons.label_outline, // custom, user-created category
      };
}

/// Merges the curated [TransactionFields.categories] with any custom
/// categories the user has already used on their own transactions, so a
/// custom category they typed once reappears as a normal option afterward.
class CategoryOptions {
  CategoryOptions._();

  static List<String> merge(List<TransactionModel> userTransactions,
      {String? mustInclude}) {
    final custom = userTransactions
        .map((t) => t.category)
        .where((c) =>
            c.isNotEmpty &&
            c != 'Transfer In' &&
            c != 'Transfer Out' &&
            !TransactionFields.categories.contains(c))
        .toSet()
        .toList()
      ..sort();
    final merged = [...TransactionFields.categories, ...custom];
    if (mustInclude != null &&
        mustInclude.isNotEmpty &&
        !merged.contains(mustInclude)) {
      merged.add(mustInclude);
    }
    return merged;
  }
}
