import '../../fraud_detection/domain/financial_health.dart';

/// The "Financial Overview Card" figures — reuses the Fraud Detection
/// module's [FinancialHealthResult] directly rather than recomputing the
/// score a third time (Budget already reuses it too — see that module's
/// `financialHealthProvider` note).
class ReportSummary {
  final double totalIncome;
  final double totalExpense;
  final double currentBalance;
  final FinancialHealthResult health;

  const ReportSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.currentBalance,
    required this.health,
  });

  double get savings => totalIncome - totalExpense;
  double get savingsRate => totalIncome > 0 ? (savings / totalIncome * 100) : 0;
}
