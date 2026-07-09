import '../../../models/budget_model.dart';
import '../../../models/transaction_model.dart';
import 'risk_level.dart';

/// The transaction being scored — not yet a [TransactionModel] since scoring
/// happens before the doc is created (or before an edit is saved).
class FraudCandidate {
  final String accountId;
  final String type;
  final String category;
  final double amount;
  final String description;
  final String merchant;
  final String paymentMethod;
  final DateTime transactionDate;
  final bool simulateNewDevice;

  const FraudCandidate({
    required this.accountId,
    required this.type,
    required this.category,
    required this.amount,
    required this.description,
    this.merchant = '',
    this.paymentMethod = '',
    required this.transactionDate,
    this.simulateNewDevice = false,
  });
}

/// Everything a rule might need: the candidate itself, the user's recent
/// transaction history (for pattern rules), the target account's current
/// balance (for the negative-balance-prediction rule), and the user's
/// active budgets (for the budget-overspending rule).
class FraudContext {
  final FraudCandidate candidate;
  final List<TransactionModel> history;
  final double currentAccountBalance;
  final List<BudgetModel> activeBudgets;

  const FraudContext({
    required this.candidate,
    required this.history,
    required this.currentAccountBalance,
    this.activeBudgets = const [],
  });
}

/// One rule's verdict when it fires.
class FraudSignal {
  final String rule;
  final int score;
  final String reason;
  final String recommendation;

  const FraudSignal({
    required this.rule,
    required this.score,
    required this.reason,
    required this.recommendation,
  });
}

/// The engine's combined verdict across every rule that fired.
class FraudAnalysisResult {
  final int score;
  final RiskLevel level;
  final List<FraudSignal> signals;

  const FraudAnalysisResult({
    required this.score,
    required this.level,
    required this.signals,
  });

  bool get isRisky => level != RiskLevel.low;

  /// Combined, human-readable explanation — the strongest signal's reason,
  /// plus a count of anything else that also fired.
  String get reason {
    if (signals.isEmpty) return 'No unusual activity detected.';
    final sorted = [...signals]..sort((a, b) => b.score.compareTo(a.score));
    final primary = sorted.first.reason;
    return sorted.length == 1
        ? primary
        : '$primary (+${sorted.length - 1} more signal${sorted.length > 2 ? 's' : ''})';
  }

  /// The strongest signal's recommendation — most actionable one to surface.
  String get recommendation => signals.isEmpty
      ? 'Keep tracking your spending regularly.'
      : (([...signals]..sort((a, b) => b.score.compareTo(a.score)))
          .first
          .recommendation);
}
