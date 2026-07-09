import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/report_providers.dart';
import '../../domain/report_date_range.dart';

/// Chip row for the 5 quick presets + a "Custom range" chip that opens
/// Flutter's Material date-range picker.
class DateRangeSelector extends ConsumerWidget {
  const DateRangeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportDateRangeProvider);
    final notifier = ref.read(reportDateRangeProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final preset in ReportRangePreset.values
                  .where((p) => p != ReportRangePreset.custom))
                _chip(context, preset.label, range.preset == preset,
                    () => notifier.setPreset(preset)),
              _chip(
                context,
                range.preset == ReportRangePreset.custom
                    ? '${DateFormat.MMMd().format(range.start)} - ${DateFormat.MMMd().format(range.end)}'
                    : 'Custom range',
                range.preset == ReportRangePreset.custom,
                () => _pickCustomRange(context, ref),
                icon: Icons.calendar_month_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${DateFormat.yMMMd().format(range.start)} – ${DateFormat.yMMMd().format(range.end)}',
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange:
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              Theme.of(context).colorScheme.copyWith(primary: AppTokens.brand),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref
          .read(reportDateRangeProvider.notifier)
          .setCustomRange(picked.start, picked.end);
    }
  }

  Widget _chip(
      BuildContext context, String label, bool selected, VoidCallback onTap,
      {IconData? icon}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected ? AppTokens.brand : scheme.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTokens.brand.withValues(alpha: 0.16),
        labelStyle: TextStyle(
            color: selected ? AppTokens.brand : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
        side: BorderSide(
            color: selected ? AppTokens.brand : scheme.outlineVariant),
      ),
    );
  }
}
