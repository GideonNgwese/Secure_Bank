import '../../../models/budget_model.dart';
import 'fraud_signal.dart';
import 'risk_level.dart';

typedef FraudRule = FraudSignal? Function(FraudContext ctx);

/// Rule-based fraud/anomaly scoring engine. Each rule is a small, pure,
/// independently testable function; the engine just runs all of them and
/// sums whatever fires (capped 0-100). New rules can be added by writing a
/// new function and appending it to [_rules] — nothing else changes (open
/// for extension, matching the fraud-detection spec's rule list).
///
/// This is a personal-finance *awareness* tool, not real bank fraud
/// detection — it flags patterns worth a second look, nothing more.
class FraudRuleEngine {
  FraudRuleEngine._();

  static final List<FraudRule> _rules = [
    _highAmountVsAverage,
    _flatLargeAmount,
    _criticalAmount,
    _rapidFireActivity,
    _highSpendingFrequency,
    _multipleLargeSameDay,
    _largeExpenseAfterSalary,
    _repeatedMerchantPayments,
    _lateNightSpending,
    _largeCashWithdrawal,
    _duplicateTransaction,
    _newDeviceFlag,
    _negativeBalancePrediction,
    _budgetOverspending,
  ];

  static FraudAnalysisResult analyze(FraudContext ctx) {
    final signals = <FraudSignal>[];
    for (final rule in _rules) {
      final signal = rule(ctx);
      if (signal != null) signals.add(signal);
    }
    final behavioralScore = signals.fold<int>(0, (s, sig) => s + sig.score);
    // The amount alone guarantees at least its band's level (RiskThresholds),
    // regardless of how any individual rule's point value is tuned — taking
    // the max keeps `riskScore`/`riskLevel` reconciled through one function
    // (fromScore) instead of two independent classification axes that could
    // disagree.
    final amountScore =
        RiskThresholds.nominalScoreForAmount(ctx.candidate.amount);
    final score =
        (behavioralScore > amountScore ? behavioralScore : amountScore)
            .clamp(0, 100);
    return FraudAnalysisResult(
        score: score, level: RiskLevelX.fromScore(score), signals: signals);
  }

  /// Rule: amount significantly higher than the user's own average.
  static FraudSignal? _highAmountVsAverage(FraudContext ctx) {
    final history = ctx.history;
    if (history.length < 3) return null;
    final avg =
        history.map((t) => t.amount).reduce((a, b) => a + b) / history.length;
    if (avg <= 0) return null;
    final ratio = ctx.candidate.amount / avg;
    if (ratio < 3) return null;
    return FraudSignal(
      rule: 'high_amount_vs_average',
      score: 30,
      reason: 'This transaction is ${ratio.toStringAsFixed(1)}x your average '
          'of ${avg.toStringAsFixed(0)} FCFA.',
      recommendation:
          'Double-check the amount before confirming — this is well above your usual spending.',
    );
  }

  /// Rule 1: amount >= 100,000 FCFA → High Risk. Catches risk even for
  /// brand-new users with too little history for [_highAmountVsAverage] to
  /// compare against. The level itself is guaranteed by [RiskThresholds] in
  /// [analyze]; this rule's score just adds to the narrative/reason.
  static FraudSignal? _flatLargeAmount(FraudContext ctx) {
    if (ctx.candidate.amount < RiskThresholds.highMin) return null;
    return const FraudSignal(
      rule: 'flat_large_amount',
      score: 15,
      reason: 'This is a large transaction (100,000 FCFA or more).',
      recommendation:
          'Review the details carefully — large one-off transactions are worth a second look.',
    );
  }

  /// Rule 2: amount >= 500,000 FCFA → Critical Risk.
  static FraudSignal? _criticalAmount(FraudContext ctx) {
    if (ctx.candidate.amount < RiskThresholds.criticalMin) return null;
    return const FraudSignal(
      rule: 'critical_amount',
      score: 30,
      reason: 'This is a critical-risk transaction (500,000 FCFA or more).',
      recommendation:
          'This is an exceptionally large transaction — verify it immediately before confirming.',
    );
  }

  /// Rule 3: more than 5 transactions of any type within 60 seconds.
  static FraudSignal? _rapidFireActivity(FraudContext ctx) {
    final windowStart =
        ctx.candidate.transactionDate.subtract(const Duration(seconds: 60));
    final count = ctx.history
        .where((t) =>
            t.transactionDate.isAfter(windowStart) &&
            t.transactionDate.isBefore(ctx.candidate.transactionDate))
        .length;
    if (count <= 5) return null;
    return FraudSignal(
      rule: 'rapid_transaction_activity',
      score: 25,
      reason: '$count transactions were recorded in the last 60 seconds.',
      recommendation:
          'A burst of activity in a few seconds can indicate a lost card or compromised wallet — confirm every one of these.',
    );
  }

  /// Rule 4: more than 10 transactions of any type in one calendar day.
  static FraudSignal? _highSpendingFrequency(FraudContext ctx) {
    final d = ctx.candidate.transactionDate;
    final sameDayCount = ctx.history
        .where((t) =>
            t.transactionDate.year == d.year &&
            t.transactionDate.month == d.month &&
            t.transactionDate.day == d.day)
        .length;
    final total = sameDayCount + 1; // + the candidate itself
    if (total <= 10) return null;
    return FraudSignal(
      rule: 'high_spending_frequency',
      score: 20,
      reason: '$total transactions were recorded today.',
      recommendation:
          'An unusually high number of transactions in one day is worth a quick review.',
    );
  }

  /// Supplementary rule: multiple large (individually, over 50,000 FCFA)
  /// transactions on the same calendar day — distinct from Rule 4's flat
  /// count of ANY transactions that day.
  static FraudSignal? _multipleLargeSameDay(FraudContext ctx) {
    const threshold = 50000.0;
    final d = ctx.candidate.transactionDate;
    final sameDayLarge = ctx.history
        .where((t) =>
            t.amount > threshold &&
            t.transactionDate.year == d.year &&
            t.transactionDate.month == d.month &&
            t.transactionDate.day == d.day)
        .length;
    final total = sameDayLarge + (ctx.candidate.amount > threshold ? 1 : 0);
    if (total < 3) return null;
    return FraudSignal(
      rule: 'multiple_large_same_day',
      score: 20,
      reason:
          '$total transactions over ${threshold.toStringAsFixed(0)} FCFA were recorded today.',
      recommendation:
          'Several large transactions in one day is unusual — make sure all of them are yours.',
    );
  }

  /// Supplementary rule: large expense immediately after a salary payment.
  static FraudSignal? _largeExpenseAfterSalary(FraudContext ctx) {
    if (ctx.candidate.type != 'Expense') return null;
    final since =
        ctx.candidate.transactionDate.subtract(const Duration(hours: 48));
    final salaryTx = ctx.history.where((t) =>
        t.type == 'Income' &&
        t.category == 'Salary' &&
        t.transactionDate.isAfter(since) &&
        t.transactionDate.isBefore(ctx.candidate.transactionDate));
    if (salaryTx.isEmpty) return null;
    final lastSalary = salaryTx
        .reduce((a, b) => a.transactionDate.isAfter(b.transactionDate) ? a : b);
    if (ctx.candidate.amount < lastSalary.amount * 0.4) return null;
    return const FraudSignal(
      rule: 'large_expense_after_salary',
      score: 20,
      reason: 'A large expense followed a salary payment within 48 hours.',
      recommendation:
          'Spending a large share of your salary right away can strain your budget — consider spacing out big purchases.',
    );
  }

  /// Rule 6: repeated payments to the same merchant in a short period →
  /// Duplicate Merchant Activity.
  static FraudSignal? _repeatedMerchantPayments(FraudContext ctx) {
    final merchant = ctx.candidate.merchant.trim().toLowerCase();
    if (merchant.isEmpty) return null;
    final since =
        ctx.candidate.transactionDate.subtract(const Duration(hours: 48));
    final count = ctx.history
        .where((t) =>
            t.merchant.trim().toLowerCase() == merchant &&
            t.transactionDate.isAfter(since) &&
            t.transactionDate.isBefore(ctx.candidate.transactionDate))
        .length;
    if (count < 3) return null;
    return FraudSignal(
      rule: 'repeated_merchant_payments',
      score: 15,
      reason:
          '${count + 1} payments to "${ctx.candidate.merchant}" within 48 hours.',
      recommendation:
          'Repeated charges from the same merchant can signal a duplicate charge or a forgotten subscription.',
    );
  }

  /// Supplementary rule: unusual late-night spending (midnight–5am).
  static FraudSignal? _lateNightSpending(FraudContext ctx) {
    if (ctx.candidate.type != 'Expense') return null;
    final hour = ctx.candidate.transactionDate.hour;
    if (hour < 0 || hour >= 5) return null;
    return const FraudSignal(
      rule: 'late_night_spending',
      score: 12,
      reason: 'This expense was recorded between midnight and 5am.',
      recommendation:
          'Late-night transactions are less common — confirm this was you.',
    );
  }

  /// Supplementary rule: very large cash withdrawal.
  static FraudSignal? _largeCashWithdrawal(FraudContext ctx) {
    final isCash = ctx.candidate.category == 'Cash' ||
        ctx.candidate.paymentMethod == 'Cash';
    if (!isCash ||
        ctx.candidate.type != 'Expense' ||
        ctx.candidate.amount <= 75000) {
      return null;
    }
    return const FraudSignal(
      rule: 'large_cash_withdrawal',
      score: 15,
      reason: 'A large cash withdrawal was recorded.',
      recommendation:
          'Large cash-outs are harder to trace than digital payments — keep a note of what it was for.',
    );
  }

  /// Duplicate amount + description on the same day (kept from the original
  /// scoring engine — still one of the strongest simple fraud signals).
  static FraudSignal? _duplicateTransaction(FraudContext ctx) {
    final d = ctx.candidate.transactionDate;
    final desc = ctx.candidate.description.trim().toLowerCase();
    final duplicate = ctx.history.any((t) =>
        t.amount == ctx.candidate.amount &&
        t.description.trim().toLowerCase() == desc &&
        t.transactionDate.year == d.year &&
        t.transactionDate.month == d.month &&
        t.transactionDate.day == d.day);
    if (!duplicate) return null;
    return const FraudSignal(
      rule: 'duplicate_transaction',
      score: 20,
      reason:
          'A transaction with the same amount and description was already recorded today.',
      recommendation:
          'Check that you have not recorded this transaction twice.',
    );
  }

  /// Simulated new device / new login flag (kept from the original engine —
  /// a stand-in for real device-fingerprint checks a future bank
  /// integration could provide).
  static FraudSignal? _newDeviceFlag(FraudContext ctx) {
    if (!ctx.candidate.simulateNewDevice) return null;
    return const FraudSignal(
      rule: 'new_device',
      score: 10,
      reason:
          'This transaction was flagged as coming from a new device or login.',
      recommendation:
          'If you did not recently sign in from a new device, secure your account immediately.',
    );
  }

  /// Rule 7: negative projected account balance → Balance Warning —
  /// immediate (this transaction alone pushes the account negative) or
  /// trend-based (recent burn rate would).
  static FraudSignal? _negativeBalancePrediction(FraudContext ctx) {
    final delta = _signedDelta(ctx.candidate);
    final projected = ctx.currentAccountBalance + delta;
    if (projected < 0) {
      return FraudSignal(
        rule: 'negative_balance_prediction',
        score: 30,
        reason:
            'Completing this transaction would take the account balance negative '
            '(projected ${projected.toStringAsFixed(0)} FCFA).',
        recommendation:
            'Consider a smaller amount or topping up the account first.',
      );
    }

    final accountHistory = ctx.history
        .where((t) => t.accountId == ctx.candidate.accountId)
        .toList();
    if (accountHistory.length < 5) return null;

    final earliest = accountHistory
        .map((t) => t.transactionDate)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final days =
        ctx.candidate.transactionDate.difference(earliest).inDays.clamp(1, 30);
    final net =
        accountHistory.fold<double>(0, (s, t) => s + t.signedAmount) + delta;
    final dailyBurn = net / days;
    if (dailyBurn < 0 && (projected + dailyBurn * 7) < 0) {
      return const FraudSignal(
        rule: 'negative_balance_trend',
        score: 15,
        reason:
            'At your recent spending rate, this account may go negative within a week.',
        recommendation:
            'Review your upcoming expenses and consider slowing down discretionary spending.',
      );
    }
    return null;
  }

  /// Rule 5: this expense would push one of the user's active budgets over
  /// 100% of its limit → Budget Overspending. Reuses [BudgetModel.spentFrom]
  /// — the same "spend so far in this budget's category + date range"
  /// formula the Budget module itself and the 80/90/100% alert check both
  /// already use, so this rule's notion of "overspending" never disagrees
  /// with what Budgets shows.
  static FraudSignal? _budgetOverspending(FraudContext ctx) {
    if (ctx.candidate.type != 'Expense') return null;

    BudgetModel? budget;
    for (final b in ctx.activeBudgets) {
      if (b.isActive &&
          b.category == ctx.candidate.category &&
          !ctx.candidate.transactionDate.isBefore(b.startDate) &&
          !ctx.candidate.transactionDate.isAfter(b.endDate)) {
        budget = b;
        break;
      }
    }
    if (budget == null || budget.budgetAmount <= 0) return null;

    final spentBefore = budget.spentFrom(ctx.history);
    final spentAfter = spentBefore + ctx.candidate.amount;
    if (spentAfter <= budget.budgetAmount) return null;

    final pct = spentAfter / budget.budgetAmount * 100;
    final name = budget.name.isNotEmpty ? budget.name : budget.category;
    return FraudSignal(
      rule: 'budget_overspending',
      score: 15,
      reason:
          'This expense pushes your "$name" budget to ${pct.toStringAsFixed(0)}% used '
          '(${spentAfter.toStringAsFixed(0)} of ${budget.budgetAmount.toStringAsFixed(0)} FCFA).',
      recommendation:
          'Consider holding off on this expense, or adjust the budget if this is expected.',
    );
  }

  static double _signedDelta(FraudCandidate c) {
    switch (c.type) {
      case 'Income':
      case 'Refund':
        return c.amount;
      case 'Expense':
        return -c.amount;
      case 'Adjustment':
        return c.amount;
      case 'Transfer':
        return c.category == 'Transfer In' ? c.amount : -c.amount;
      default:
        return 0;
    }
  }
}
