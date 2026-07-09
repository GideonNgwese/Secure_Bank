import 'package:flutter/material.dart';

import '../../../models/budget_model.dart';
import '../../../utils/constants.dart';

/// Progress color tiers, per the design spec:
/// Safe (0-60%) blue, Warning (61-85%) orange, Critical (86-100%) red,
/// Exceeded (>100%) dark red.
enum BudgetRiskTier { safe, warning, critical, exceeded }

extension BudgetRiskTierX on BudgetRiskTier {
  String get label => switch (this) {
        BudgetRiskTier.safe => 'On track',
        BudgetRiskTier.warning => 'Watch spending',
        BudgetRiskTier.critical => 'Almost exceeded',
        BudgetRiskTier.exceeded => 'Exceeded',
      };

  Color get color => switch (this) {
        BudgetRiskTier.safe => AppColors.primary,
        BudgetRiskTier.warning => AppColors.warning,
        BudgetRiskTier.critical => AppColors.danger,
        BudgetRiskTier.exceeded => AppColors.critical,
      };

  static BudgetRiskTier fromPercent(double pct) {
    if (pct > 100) return BudgetRiskTier.exceeded;
    if (pct > 85) return BudgetRiskTier.critical;
    if (pct > 60) return BudgetRiskTier.warning;
    return BudgetRiskTier.safe;
  }
}

/// A budget paired with its live-computed spend — spending is never stored,
/// always derived from the user's transactions (see [BudgetModel]'s doc
/// comment for why).
class BudgetWithProgress {
  final BudgetModel budget;
  final double spentAmount;

  const BudgetWithProgress(this.budget, this.spentAmount);

  double get remainingAmount => budget.budgetAmount - spentAmount;

  double get percentUsed =>
      budget.budgetAmount > 0 ? (spentAmount / budget.budgetAmount * 100) : 0;

  BudgetRiskTier get tier => BudgetRiskTierX.fromPercent(percentUsed);

  bool get isEnded => DateTime.now().isAfter(budget.endDate);

  int get totalDays =>
      budget.endDate.difference(budget.startDate).inDays.clamp(1, 100000);

  int get daysRemaining {
    final now = DateTime.now();
    if (now.isBefore(budget.startDate)) return totalDays;
    return budget.endDate.difference(now).inDays.clamp(0, totalDays);
  }

  double get timeElapsedFraction {
    final now = DateTime.now();
    if (now.isBefore(budget.startDate)) return 0;
    if (now.isAfter(budget.endDate)) return 1;
    return now.difference(budget.startDate).inHours /
        (budget.endDate.difference(budget.startDate).inHours).clamp(1, 1 << 30);
  }

  /// Derived, filterable status — NOT the same as [BudgetModel.status]
  /// (which only ever holds Active/Archived); Exceeded/Completed are always
  /// computed from live spend and the current date so they can never drift.
  String get displayStatus {
    if (budget.isArchived) return 'Archived';
    if (percentUsed > 100) return 'Exceeded';
    if (isEnded) return 'Completed';
    return 'Active';
  }

  /// Simple linear projection: if spending continues at the same average
  /// daily rate, will this budget run out before the period ends?
  bool get isProjectedToExceed {
    if (isEnded || percentUsed > 100) return false;
    final elapsedDays = totalDays * timeElapsedFraction;
    if (elapsedDays < 1) return false;
    final dailyRate = spentAmount / elapsedDays;
    final projectedTotal = dailyRate * totalDays;
    return projectedTotal > budget.budgetAmount;
  }

  /// Days until projected overspend, if [isProjectedToExceed].
  int? get daysUntilProjectedExceed {
    if (!isProjectedToExceed) return null;
    final elapsedDays = totalDays * timeElapsedFraction;
    final dailyRate = spentAmount / elapsedDays;
    if (dailyRate <= 0) return null;
    final daysUntilExceed = (budget.budgetAmount - spentAmount) / dailyRate;
    return daysUntilExceed.floor().clamp(0, daysRemaining);
  }
}

/// The next period's date range — same duration, starting right after the
/// current period ends. Used by the "Reset Budget" quick action to roll a
/// budget forward without the user re-entering everything.
({DateTime start, DateTime end}) nextPeriodRange(BudgetModel b) {
  final duration = b.endDate.difference(b.startDate);
  final newStart = b.endDate.add(const Duration(seconds: 1));
  return (start: newStart, end: newStart.add(duration));
}
