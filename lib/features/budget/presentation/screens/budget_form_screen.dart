import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../models/budget_model.dart';
import '../../../transactions/presentation/widgets/category_picker.dart';
import '../../data/budget_providers.dart';
import '../../domain/budget_fields.dart';
import '../../domain/budget_validators.dart';
import '../controllers/budget_form_controller.dart';
import '../widgets/budget_color_icon_picker.dart';

/// Premium create/edit budget form. Picking a standard period auto-fills a
/// sensible start/end date range (still user-editable) — Custom leaves the
/// dates untouched for the user to pick freely.
class BudgetFormScreen extends ConsumerStatefulWidget {
  final String userId;
  final BudgetModel? existing;
  const BudgetFormScreen({super.key, required this.userId, this.existing});

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  late String _category;
  late String _currency;
  late String _period;
  late DateTime _startDate;
  late DateTime _endDate;
  late Color _color;
  late String _icon;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existing;
    _name = TextEditingController(text: b?.name ?? '');
    _amount = TextEditingController(
        text: b != null ? b.budgetAmount.toStringAsFixed(0) : '');
    _notes = TextEditingController(text: b?.notes ?? '');

    _category = b?.category ?? BudgetFields.categories.first;
    _currency = b?.currency ?? 'FCFA';
    _period = b?.period ?? 'Monthly';
    _color = b != null ? Color(b.color) : BudgetFields.palette.first;
    _icon = b?.icon.isNotEmpty == true
        ? b!.icon
        : BudgetFields.defaultIconFor(_category);

    if (b != null) {
      _startDate = b.startDate;
      _endDate = b.endDate;
    } else {
      final range = _rangeFor(_period, DateTime.now());
      _startDate = range.start;
      _endDate = range.end;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  ({DateTime start, DateTime end}) _rangeFor(String period, DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    switch (period) {
      case 'Daily':
        return (
          start: today,
          end: today.add(const Duration(hours: 23, minutes: 59, seconds: 59))
        );
      case 'Weekly':
        final start = today.subtract(Duration(days: today.weekday - 1));
        return (
          start: start,
          end: start
              .add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59))
        );
      case 'Monthly':
        final start = DateTime(from.year, from.month, 1);
        final end = DateTime(from.year, from.month + 1, 0, 23, 59, 59);
        return (start: start, end: end);
      case 'Quarterly':
        final qStartMonth = ((from.month - 1) ~/ 3) * 3 + 1;
        final start = DateTime(from.year, qStartMonth, 1);
        final end = DateTime(from.year, qStartMonth + 3, 0, 23, 59, 59);
        return (start: start, end: end);
      case 'Yearly':
        return (
          start: DateTime(from.year, 1, 1),
          end: DateTime(from.year, 12, 31, 23, 59, 59)
        );
      default: // Custom — leave as today..today, user picks their own range
        return (start: today, end: today);
    }
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _period = period;
      if (period != 'Custom') {
        final range = _rangeFor(period, DateTime.now());
        _startDate = range.start;
        _endDate = range.end;
      }
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
      helpText: isStart ? 'Start date' : 'End date',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
      } else {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Future<void> _pickCategory() async {
    final budgets =
        ref.read(budgetsRawProvider(widget.userId)).valueOrNull ?? [];
    final options =
        BudgetCategoryOptions.merge(budgets, mustInclude: _category);
    final picked = await showCategoryPicker(context,
        options: options, selected: _category);
    if (picked != null) setState(() => _category = picked);
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final dateError = BudgetValidators.dateRange(_startDate, _endDate);
    if (dateError != null) {
      _snack(dateError);
      return;
    }

    final existingBudgets =
        ref.read(budgetsRawProvider(widget.userId)).valueOrNull ?? [];
    final overlaps = BudgetValidators.hasOverlappingActiveBudget(
      existing: existingBudgets,
      category: _category,
      start: _startDate,
      end: _endDate,
      excludeId: widget.existing?.id,
    );
    if (overlaps) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Overlapping budget'),
          content:
              Text('You already have an active budget for $_category covering '
                  'part of this period. Create it anyway?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create anyway')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    if (!mounted) return;

    FocusScope.of(context).unfocus();
    final controller = ref.read(budgetFormControllerProvider.notifier);
    final amount = double.tryParse(_amount.text.trim()) ?? 0;

    final ok = _isEditing
        ? await controller.updateBudget(widget.existing!.copyWith(
            name: _name.text.trim(),
            category: _category,
            budgetAmount: amount,
            currency: _currency,
            period: _period,
            startDate: _startDate,
            endDate: _endDate,
            color: _color.toARGB32(),
            icon: _icon,
            notes: _notes.text.trim(),
          ))
        : await controller.create(BudgetModel(
            id: const Uuid().v4(),
            userId: widget.userId,
            name: _name.text.trim(),
            category: _category,
            budgetAmount: amount,
            currency: _currency,
            period: _period,
            startDate: _startDate,
            endDate: _endDate,
            color: _color.toARGB32(),
            icon: _icon,
            notes: _notes.text.trim(),
            createdAt: DateTime.now(),
          ));

    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(budgetFormControllerProvider, (_, next) {
      if (next is AsyncError) _snack((next.error as AppException).message);
    });
    final saving = ref.watch(budgetFormControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit budget' : 'Create budget')),
      body: ResponsiveCenter(
        maxWidth: 560,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(child: _previewCard()),
              const SizedBox(height: 18),
              FadeSlideIn(
                duration: const Duration(milliseconds: 500),
                child: _Section(title: 'Details', children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                        labelText: 'Budget name',
                        prefixIcon: Icon(Icons.badge_outlined, size: 20)),
                    validator: BudgetValidators.name,
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppTokens.radius),
                    onTap: _pickCategory,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined, size: 20)),
                      child: Row(
                        children: [
                          Icon(
                              BudgetFields.icons[
                                  BudgetFields.defaultIconFor(_category)],
                              size: 16),
                          const SizedBox(width: 8),
                          Text(_category),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                              labelText: 'Budget amount',
                              prefixIcon:
                                  Icon(Icons.payments_outlined, size: 20)),
                          validator: BudgetValidators.amount,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _currency,
                          decoration:
                              const InputDecoration(labelText: 'Currency'),
                          items: BudgetFields.currencies
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => setState(() => _currency = v!),
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                duration: const Duration(milliseconds: 550),
                child: _Section(title: 'Period', children: [
                  DropdownButtonFormField<String>(
                    initialValue: _period,
                    decoration: const InputDecoration(
                        labelText: 'Budget period',
                        prefixIcon: Icon(Icons.repeat, size: 20)),
                    items: BudgetFields.periods
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => _onPeriodChanged(v!),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: _dateTile('Start date', _startDate,
                              () => _pickDate(isStart: true))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _dateTile('End date', _endDate,
                              () => _pickDate(isStart: false))),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                duration: const Duration(milliseconds: 600),
                child: _Section(title: 'Appearance', children: [
                  Text('Color',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  BudgetColorPicker(
                      selected: _color,
                      onChanged: (c) => setState(() => _color = c)),
                  const SizedBox(height: 16),
                  Text('Icon',
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  BudgetIconPicker(
                      selected: _icon,
                      accent: _color,
                      onChanged: (i) => setState(() => _icon = i)),
                ]),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                duration: const Duration(milliseconds: 650),
                child: _Section(title: 'Notes', children: [
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Optional notes',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_outlined, size: 20)),
                  ),
                ]),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                duration: const Duration(milliseconds: 700),
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTokens.brand),
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(_isEditing ? 'Save changes' : 'Create budget'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewCard() {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color, _color.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: [
          BoxShadow(
              color: _color.withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(
                    BudgetFields.icons[_icon] ?? Icons.category_outlined,
                    color: Colors.white,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_name.text.isEmpty ? 'Budget name' : _name.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
              amount > 0
                  ? '${amount.toStringAsFixed(0)} $_currency'
                  : '0 $_currency',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$_category • $_period',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radius),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20)),
        child: Text(DateFormat.yMMMd().format(date)),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
