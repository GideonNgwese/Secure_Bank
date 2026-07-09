import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../fraud_detection/domain/chart_data.dart' show CategorySlice;
import '../../domain/budget_performance.dart';
import '../../domain/fraud_summary.dart';
import '../../domain/income_analytics.dart';
import '../../domain/report_date_range.dart';
import '../../domain/report_summary.dart';

const _navy = PdfColor.fromInt(0xFF0A1B3D);
const _electricBlue = PdfColor.fromInt(0xFF3E74FF);
const _muted = PdfColor.fromInt(0xFF7A8699);
const _success = PdfColor.fromInt(0xFF1FA96A);
const _danger = PdfColor.fromInt(0xFFE84C4C);
const _borderColor = PdfColor.fromInt(0xFFE2E6EF);

String _fcfa(double v) {
  final isNeg = v < 0;
  final s = v.abs().toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${isNeg ? '-' : ''}$buf FCFA';
}

/// Builds a branded, bank-statement-style PDF report — the same figures the
/// Reports dashboard shows, laid out for print/share. Pure builder: takes
/// already-computed domain objects, returns bytes; the caller (a
/// controller) hands those bytes to `package:printing` for preview/share.
class ReportPdfService {
  Future<Uint8List> build({
    required String userName,
    required ReportDateRange range,
    required ReportSummary summary,
    required IncomeAnalytics income,
    required List<CategorySlice> expenseByCategory,
    required BudgetPerformance budgets,
    required FraudSummary fraud,
    required List<String> recommendations,
  }) async {
    final doc = pw.Document();
    pw.MemoryImage? logo;
    try {
      final bytes = await rootBundle.load('assets/logo/logo.png');
      logo = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      // Logo is optional — the report still renders fine without it.
    }

    final generatedAt = DateFormat.yMMMd().add_jm().format(DateTime.now());
    final rangeLabel =
        '${DateFormat.yMMMd().format(range.start)} – ${DateFormat.yMMMd().format(range.end)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _header(logo, userName, rangeLabel, generatedAt),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ),
        build: (context) => [
          pw.SizedBox(height: 16),
          _sectionTitle('Financial overview'),
          _overviewCards(summary),
          pw.SizedBox(height: 20),
          _sectionTitle('Income summary'),
          _incomeTable(income),
          pw.SizedBox(height: 20),
          _sectionTitle('Expense summary'),
          _expenseTable(expenseByCategory, summary.totalExpense),
          pw.SizedBox(height: 20),
          _sectionTitle('Budget performance'),
          _budgetTable(budgets),
          pw.SizedBox(height: 20),
          _sectionTitle('Fraud & risk summary'),
          _fraudTable(fraud),
          pw.SizedBox(height: 20),
          _sectionTitle('Recommendations'),
          _recommendations(recommendations),
          pw.SizedBox(height: 24),
          pw.Divider(color: _borderColor),
          pw.SizedBox(height: 6),
          pw.Text(
            'This report reflects records manually entered into SecureBank and is not an '
            'official statement from any bank or mobile money provider. Fraud/risk figures '
            'are awareness indicators, not confirmed fraud findings.',
            style: const pw.TextStyle(fontSize: 7.5, color: _muted),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _header(pw.MemoryImage? logo, String userName, String rangeLabel,
      String generatedAt) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              children: [
                if (logo != null) pw.Image(logo, height: 32, width: 32),
                if (logo != null) pw.SizedBox(width: 10),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SecureBank',
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: _navy)),
                    pw.Text('Financial Report',
                        style: const pw.TextStyle(fontSize: 10, color: _muted)),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(userName,
                    style: pw.TextStyle(
                        fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(rangeLabel,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
                pw.Text('Generated $generatedAt',
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: _electricBlue, thickness: 1.4),
      ],
    );
  }

  pw.Widget _sectionTitle(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(title,
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: _navy)),
      );

  pw.Widget _overviewCards(ReportSummary s) {
    pw.Widget card(String label, String value, PdfColor color) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF5F7FB),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: _borderColor),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
                pw.SizedBox(height: 4),
                pw.Text(value,
                    style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: color)),
              ],
            ),
          ),
        );

    return pw.Column(
      children: [
        pw.Row(children: [
          card('Total income', _fcfa(s.totalIncome), _success),
          card('Total expenses', _fcfa(s.totalExpense), _danger),
        ]),
        pw.SizedBox(height: 8),
        pw.Row(children: [
          card(
              'Savings', _fcfa(s.savings), s.savings >= 0 ? _success : _danger),
          card('Current balance', _fcfa(s.currentBalance), _electricBlue),
        ]),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _navy,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Financial Health Score',
                  style:
                      const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
              pw.Text('${s.health.score}/100 · ${s.health.label}',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _incomeTable(IncomeAnalytics income) {
    if (income.sources.isEmpty) {
      return pw.Text('No income recorded for this period.',
          style: const pw.TextStyle(fontSize: 9, color: _muted));
    }
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _electricBlue),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
      },
      headers: ['Source', 'Amount', '% of income', 'Growth'],
      data: [
        for (final src in income.sources)
          [
            src.category,
            _fcfa(src.amount),
            '${src.percentage.toStringAsFixed(0)}%',
            '${src.growthPct >= 0 ? '+' : ''}${src.growthPct.toStringAsFixed(0)}%',
          ],
      ],
    );
  }

  pw.Widget _expenseTable(List<CategorySlice> slices, double total) {
    if (slices.isEmpty) {
      return pw.Text('No expenses recorded for this period.',
          style: const pw.TextStyle(fontSize: 9, color: _muted));
    }
    return pw.Column(
      children: [
        for (final c in slices) _barRow(c.category, c.amount, total),
      ],
    );
  }

  /// The `pdf` package has no `FractionallySizedBox` — proportional bars are
  /// built with `Expanded(flex:)` inside a `Row` instead, at a resolution of
  /// 1000 (i.e. flex values are per-mille, not percent, for finer steps).
  pw.Widget _barRow(String label, double amount, double total) {
    final pct = (total > 0 ? (amount / total) : 0.0).clamp(0.0, 1.0);
    final filledFlex = (pct * 1000).round();
    final remainderFlex = 1000 - filledFlex;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
              pw.Text('${_fcfa(amount)}  (${(pct * 100).toStringAsFixed(0)}%)',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            children: [
              if (filledFlex > 0)
                pw.Expanded(
                    flex: filledFlex,
                    child: pw.Container(height: 6, color: _electricBlue)),
              if (remainderFlex > 0)
                pw.Expanded(
                    flex: remainderFlex,
                    child: pw.Container(
                        height: 6, color: PdfColor.fromInt(0xFFEFF2F7))),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _budgetTable(BudgetPerformance b) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _navy),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headers: ['Budgeted', 'Used', 'Remaining', 'Exceeded', 'Successful'],
          data: [
            [
              _fcfa(b.totalBudgeted),
              _fcfa(b.totalUsed),
              _fcfa(b.totalRemaining),
              '${b.exceededCount}',
              '${b.successfulCount}',
            ],
          ],
        ),
        if (b.budgets.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          for (final item in b.budgets)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${item.budget.name} (${item.budget.category})',
                      style: const pw.TextStyle(fontSize: 8.5)),
                  pw.Text('${item.percentUsed.toStringAsFixed(0)}% used',
                      style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: item.percentUsed > 100
                              ? _danger
                              : _electricBlue)),
                ],
              ),
            ),
        ],
      ],
    );
  }

  pw.Widget _fraudTable(FraudSummary f) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _danger),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headers: [
        'Total alerts',
        'Low',
        'Medium',
        'High',
        'Critical',
        'Resolved',
        'Suspicious tx'
      ],
      data: [
        [
          '${f.totalAlerts}',
          '${f.lowCount}',
          '${f.mediumCount}',
          '${f.highCount}',
          '${f.criticalCount}',
          '${f.resolvedCount}',
          '${f.suspiciousTransactionCount}',
        ],
      ],
    );
  }

  pw.Widget _recommendations(List<String> tips) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final tip in tips)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('•  ',
                    style: pw.TextStyle(fontSize: 9, color: _electricBlue)),
                pw.Expanded(
                    child:
                        pw.Text(tip, style: const pw.TextStyle(fontSize: 9))),
              ],
            ),
          ),
      ],
    );
  }
}
