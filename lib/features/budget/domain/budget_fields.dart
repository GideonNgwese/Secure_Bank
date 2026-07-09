import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/budget_model.dart';
import '../../../utils/constants.dart';

class BudgetFields {
  BudgetFields._();

  static const List<String> periods = [
    'Daily',
    'Weekly',
    'Monthly',
    'Quarterly',
    'Yearly',
    'Custom',
  ];

  /// Budgets target spending, so income-only categories (Salary) are
  /// excluded. Otherwise shares `kCategories` with Transactions so a budget
  /// category always matches a selectable transaction category.
  static final List<String> categories =
      kCategories.where((c) => c != 'Salary').toList();

  static const List<String> currencies = ['FCFA', 'USD', 'EUR', 'GBP'];

  static const List<String> statuses = ['Active', 'Archived'];

  /// Curated color palette users can pick for a budget's card/progress bar.
  static const List<Color> palette = [
    AppTokens.brand,
    AppTokens.brandDeep,
    AppTokens.accent,
    AppTokens.success,
    AppTokens.warning,
    Color(0xFFE0218A),
    Color(0xFF00B4DB),
    Color(0xFF6B7280),
    Color(0xFFE95D2A),
    Color(0xFF1B7A3D),
  ];

  /// Curated icon set, stored as a string key (not a raw codepoint, which
  /// isn't stable across icon font versions).
  static const Map<String, IconData> icons = {
    'food': Icons.restaurant_outlined,
    'transport': Icons.directions_bus_outlined,
    'shopping': Icons.shopping_bag_outlined,
    'bills': Icons.receipt_outlined,
    'entertainment': Icons.movie_outlined,
    'healthcare': Icons.local_hospital_outlined,
    'education': Icons.school_outlined,
    'utilities': Icons.bolt_outlined,
    'travel': Icons.flight_takeoff_outlined,
    'savings': Icons.savings_outlined,
    'business': Icons.storefront_outlined,
    'investment': Icons.trending_up_rounded,
    'insurance': Icons.shield_outlined,
    'rent': Icons.home_outlined,
    'mobile_money': Icons.smartphone_outlined,
    'cash': Icons.payments_outlined,
    'gift': Icons.card_giftcard_outlined,
    'wallet': Icons.account_balance_wallet_outlined,
    'chart': Icons.pie_chart_outline,
    'target': Icons.track_changes_outlined,
    'other': Icons.category_outlined,
  };

  /// Sensible default icon key per category, so a fresh budget looks right
  /// before the user picks anything.
  static String defaultIconFor(String category) => switch (category) {
        'Food' => 'food',
        'Transport' => 'transport',
        'Shopping' => 'shopping',
        'Bills' => 'bills',
        'Entertainment' => 'entertainment',
        'Healthcare' => 'healthcare',
        'Education' => 'education',
        'Utilities' => 'utilities',
        'Travel' => 'travel',
        'Savings' => 'savings',
        'Business' => 'business',
        'Investment' => 'investment',
        'Insurance' => 'insurance',
        'Rent' => 'rent',
        'Mobile Money' => 'mobile_money',
        'Cash' => 'cash',
        'Gift' => 'gift',
        _ => 'other',
      };

  static IconData iconFor(BudgetModel b) =>
      icons[b.icon] ?? icons[defaultIconFor(b.category)] ?? icons['other']!;
}

/// Merges the curated [BudgetFields.categories] with any custom categories
/// the user has already used on their own budgets, so a custom category
/// typed once reappears as a normal option afterward.
class BudgetCategoryOptions {
  BudgetCategoryOptions._();

  static List<String> merge(List<BudgetModel> userBudgets,
      {String? mustInclude}) {
    final custom = userBudgets
        .map((b) => b.category)
        .where((c) => c.isNotEmpty && !BudgetFields.categories.contains(c))
        .toSet()
        .toList()
      ..sort();
    final merged = [...BudgetFields.categories, ...custom];
    if (mustInclude != null &&
        mustInclude.isNotEmpty &&
        !merged.contains(mustInclude)) {
      merged.add(mustInclude);
    }
    return merged;
  }
}
