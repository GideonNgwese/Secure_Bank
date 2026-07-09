import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/transaction_model.dart';
import '../../../../utils/constants.dart';
import '../../../fraud_detection/domain/chart_data.dart';
import 'report_card.dart';

const _palette = [
  AppTokens.brand,
  AppTokens.accent,
  Color(0xFFE0218A),
  Color(0xFF00B4DB),
  AppTokens.success,
  AppTokens.warning,
  Color(0xFF6B7280),
];

/// Expense Analytics: a pie/donut toggle (same data, different visual —
/// satisfies both chart types the spec asks for) and a tappable category
/// list that opens the period's transactions for that category.
class ExpenseAnalyticsSection extends StatefulWidget {
  final List<CategorySlice> slices;
  final List<TransactionModel> periodTx;
  const ExpenseAnalyticsSection(
      {super.key, required this.slices, required this.periodTx});

  @override
  State<ExpenseAnalyticsSection> createState() =>
      _ExpenseAnalyticsSectionState();
}

class _ExpenseAnalyticsSectionState extends State<ExpenseAnalyticsSection> {
  bool _donut = true;

  void _openCategory(BuildContext context, CategorySlice slice) {
    final txs = widget.periodTx
        .where((t) => t.type == 'Expense' && t.category == slice.category)
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 16),
            Text(slice.category,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
                '${formatFCFA(slice.amount)} across ${txs.length} transaction${txs.length == 1 ? '' : 's'}',
                style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            for (final t in txs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              t.title.isNotEmpty
                                  ? t.title
                                  : (t.description.isNotEmpty
                                      ? t.description
                                      : t.category),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(DateFormat.yMMMd().format(t.transactionDate),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Text('-${formatFCFA(t.amount)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.critical)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.slices.isEmpty) {
      return ReportCard(
        title: 'Expense breakdown',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('No expenses recorded for this period.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ),
      );
    }

    final total = widget.slices.fold<double>(0, (s, c) => s + c.amount);
    return ReportCard(
      title: 'Expense breakdown',
      trailing: _toggle(),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: _donut ? 46 : 0,
                sections: [
                  for (var i = 0; i < widget.slices.length; i++)
                    PieChartSectionData(
                      value: widget.slices[i].amount,
                      color: _palette[i % _palette.length],
                      title:
                          '${(widget.slices[i].amount / total * 100).toStringAsFixed(0)}%',
                      radius: 58,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < widget.slices.length; i++)
            _categoryRow(context, widget.slices[i], total,
                _palette[i % _palette.length]),
        ],
      ),
    );
  }

  Widget _toggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton('Donut', _donut, () => setState(() => _donut = true)),
          _toggleButton('Pie', !_donut, () => setState(() => _donut = false)),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: selected ? AppTokens.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(16)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5,
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _categoryRow(
      BuildContext context, CategorySlice slice, double total, Color color) {
    final scheme = Theme.of(context).colorScheme;
    final pct = total > 0 ? slice.amount / total * 100 : 0;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openCategory(context, slice),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
                child: Text(slice.category,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600))),
            Text(formatFCFA(slice.amount),
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            SizedBox(
              width: 38,
              child: Text('${pct.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ),
            Icon(Icons.chevron_right, size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
