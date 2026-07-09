import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../../../../models/transaction_model.dart';
import '../../../fraud_detection/domain/chart_data.dart' show CategorySlice;
import '../../domain/budget_performance.dart';
import '../../domain/fraud_summary.dart';
import '../../domain/income_analytics.dart';
import '../../domain/report_date_range.dart';
import '../../domain/report_summary.dart';

/// Builds the same figures as the PDF report into a CSV — a plain-text
/// export a spreadsheet can open, and a superset of what the old Reports
/// screen produced (summary + category breakdown + fraud counts + the raw
/// transaction list for the period).
class ReportCsvService {
  String build({
    required ReportDateRange range,
    required ReportSummary summary,
    required IncomeAnalytics income,
    required List<CategorySlice> expenseByCategory,
    required BudgetPerformance budgets,
    required FraudSummary fraud,
    required List<TransactionModel> periodTx,
    required Map<String, String> accountNames,
  }) {
    final rangeLabel =
        '${DateFormat.yMMMd().format(range.start)} to ${DateFormat.yMMMd().format(range.end)}';

    final rows = <List<dynamic>>[
      ['SecureBank Financial Report', rangeLabel],
      [],
      ['FINANCIAL OVERVIEW'],
      ['Total Income (FCFA)', summary.totalIncome.toStringAsFixed(0)],
      ['Total Expenses (FCFA)', summary.totalExpense.toStringAsFixed(0)],
      ['Savings (FCFA)', summary.savings.toStringAsFixed(0)],
      ['Current Balance (FCFA)', summary.currentBalance.toStringAsFixed(0)],
      [
        'Financial Health Score',
        '${summary.health.score}/100 (${summary.health.label})'
      ],
      [],
      ['INCOME BY SOURCE'],
      ['Source', 'Amount (FCFA)', '% of income', 'Growth vs previous period'],
      ...income.sources.map((s) => [
            s.category,
            s.amount.toStringAsFixed(0),
            '${s.percentage.toStringAsFixed(0)}%',
            '${s.growthPct.toStringAsFixed(0)}%',
          ]),
      [],
      ['EXPENSES BY CATEGORY'],
      ['Category', 'Amount (FCFA)', '% of expenses'],
      ...expenseByCategory.map((c) => [
            c.category,
            c.amount.toStringAsFixed(0),
            summary.totalExpense > 0
                ? '${(c.amount / summary.totalExpense * 100).toStringAsFixed(0)}%'
                : '0%',
          ]),
      [],
      ['BUDGET PERFORMANCE'],
      ['Total Budgeted (FCFA)', budgets.totalBudgeted.toStringAsFixed(0)],
      ['Total Used (FCFA)', budgets.totalUsed.toStringAsFixed(0)],
      ['Total Remaining (FCFA)', budgets.totalRemaining.toStringAsFixed(0)],
      ['Exceeded Budgets', budgets.exceededCount],
      ['Successful Budgets', budgets.successfulCount],
      ['Budget Name', 'Category', '% Used'],
      ...budgets.budgets.map((b) => [
            b.budget.name,
            b.budget.category,
            '${b.percentUsed.toStringAsFixed(0)}%',
          ]),
      [],
      ['FRAUD & RISK SUMMARY'],
      ['Total Alerts', fraud.totalAlerts],
      ['Low Risk', fraud.lowCount],
      ['Medium Risk', fraud.mediumCount],
      ['High Risk', fraud.highCount],
      ['Critical Risk', fraud.criticalCount],
      ['Resolved Alerts', fraud.resolvedCount],
      ['Suspicious Transactions', fraud.suspiciousTransactionCount],
      [],
      ['TRANSACTIONS ($rangeLabel)'],
      [
        'Date',
        'Account',
        'Type',
        'Category',
        'Amount (FCFA)',
        'Description',
        'Risk'
      ],
      ...periodTx.map((t) => [
            DateFormat('yyyy-MM-dd').format(t.transactionDate),
            accountNames[t.accountId] ?? 'Unknown',
            t.type,
            t.category,
            t.amount.toStringAsFixed(0),
            t.description,
            t.riskLevel,
          ]),
    ];
    return Csv().encode(rows);
  }
}
