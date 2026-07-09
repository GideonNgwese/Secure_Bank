import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/budget_model.dart';
import '../../../../utils/constants.dart';
import '../../data/budget_providers.dart';
import '../../domain/budget_fields.dart';
import '../../domain/budget_view.dart';
import '../controllers/budget_form_controller.dart';
import 'budget_form_screen.dart';
import 'budget_list_screen.dart' show showBudgetActionsSheet;

class BudgetDetailScreen extends ConsumerWidget {
  final String userId;
  final String budgetId;
  const BudgetDetailScreen(
      {super.key, required this.userId, required this.budgetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allBudgetsWithProgressProvider(userId));
    final item =
        allAsync.valueOrNull?.where((b) => b.budget.id == budgetId).firstOrNull;

    if (item == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final b = item.budget;
    final color = Color(b.color);
    final tierColor = item.tier.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => showBudgetActionsSheet(
                context, ref, b, () => _openEdit(context, b)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.32),
                      blurRadius: 20,
                      offset: const Offset(0, 12)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: 'budget-icon-${b.id}',
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(BudgetFields.iconFor(b),
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(b.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(item.displayStatus,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                      '${formatFCFA(item.spentAmount)} of ${formatFCFA(b.budgetAmount)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                          begin: 0, end: (item.percentUsed / 100).clamp(0, 1)),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, _) => LinearProgressIndicator(
                        value: t,
                        minHeight: 10,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.percentUsed.toStringAsFixed(0)}% used',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text(
                          item.remainingAmount >= 0
                              ? '${formatFCFA(item.remainingAmount)} remaining'
                              : '${formatFCFA(item.remainingAmount.abs())} over',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (item.isProjectedToExceed)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTokens.radius),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'At this rate, you may exceed this budget within '
                      '${item.daysUntilProjectedExceed ?? 0} day(s).',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          _detailsCard(context, item, tierColor),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openEdit(context, b),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit budget'),
              style: FilledButton.styleFrom(backgroundColor: AppTokens.brand),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref
                    .read(budgetFormControllerProvider.notifier)
                    .duplicate(b, const Uuid().v4());
                if (context.mounted) Navigator.of(context).maybePop();
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Duplicate budget'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _confirmDelete(context, ref, b),
            icon: const Icon(Icons.delete_outline, color: AppColors.critical),
            label: const Text('Delete budget',
                style: TextStyle(color: AppColors.critical)),
          ),
        ],
      ),
    );
  }

  void _openEdit(BuildContext context, BudgetModel b) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BudgetFormScreen(userId: userId, existing: b)));

  Widget _detailsCard(
      BuildContext context, BudgetWithProgress item, Color tierColor) {
    final b = item.budget;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final updated = b.updatedAt ?? b.createdAt;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          _row(context, 'Category', b.category),
          _row(context, 'Period', b.period),
          _row(context, 'Start date', DateFormat.yMMMd().format(b.startDate)),
          _row(context, 'End date', DateFormat.yMMMd().format(b.endDate)),
          _row(context, 'Days remaining',
              item.isEnded ? 'Ended' : '${item.daysRemaining} days'),
          _row(context, 'Currency', b.currency),
          _row(context, 'Status', item.displayStatus),
          if (b.notes.isNotEmpty) _row(context, 'Notes', b.notes),
          _row(context, 'Created', DateFormat.yMMMd().format(b.createdAt)),
          _row(context, 'Updated', DateFormat.yMMMd().format(updated),
              last: true),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool last = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              Flexible(
                child: Text(value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
          if (!last) const Divider(height: 16),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, BudgetModel b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this budget?'),
        content: Text(
            'This removes "${b.name}". Its past spending stays visible on your '
            'transactions, just no longer tracked against a budget.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.critical),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(budgetFormControllerProvider.notifier).delete(b.id);
      if (context.mounted) Navigator.of(context).maybePop();
    }
  }
}
