import 'package:flutter/material.dart';

import '../../domain/budget_fields.dart';

/// Inline color-swatch row for picking a budget's accent color.
class BudgetColorPicker extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onChanged;
  const BudgetColorPicker(
      {super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final c in BudgetFields.palette)
          GestureDetector(
            onTap: () => onChanged(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                    color: c == selected ? Colors.white : Colors.transparent,
                    width: 3),
                boxShadow: c == selected
                    ? [
                        BoxShadow(
                            color: c.withValues(alpha: 0.5), blurRadius: 8)
                      ]
                    : null,
              ),
              child: c == selected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Inline icon-grid picker for a budget's icon (independent of the
/// category-derived default — the user can always override it).
class BudgetIconPicker extends StatelessWidget {
  final String selected;
  final Color accent;
  final ValueChanged<String> onChanged;
  const BudgetIconPicker(
      {super.key,
      required this.selected,
      required this.accent,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final entry in BudgetFields.icons.entries)
          GestureDetector(
            onTap: () => onChanged(entry.key),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: entry.key == selected
                    ? accent.withValues(alpha: 0.16)
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(
                    color: entry.key == selected ? accent : Colors.transparent,
                    width: 1.6),
              ),
              child: Icon(entry.value,
                  size: 19,
                  color:
                      entry.key == selected ? accent : scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
