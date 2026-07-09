import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/transaction_fields.dart';

/// Opens a searchable category picker with an inline "create new" flow.
/// Returns the chosen category name, or null if dismissed without a choice.
Future<String?> showCategoryPicker(
  BuildContext context, {
  required List<String> options,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _CategoryPickerSheet(options: options, selected: selected),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  final List<String> options;
  final String? selected;
  const _CategoryPickerSheet({required this.options, required this.selected});

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _search = TextEditingController();
  final _newCategory = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _search.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((c) => c.toLowerCase().contains(q)).toList();
  }

  void _createCustom() {
    final name = _newCategory.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Select category',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search categories',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in _filtered)
                        _CategoryChip(
                          label: c,
                          selected: c == widget.selected,
                          onTap: () => Navigator.of(context).pop(c),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _creating
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newCategory,
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                hintText: 'New category name',
                                isDense: true,
                              ),
                              onSubmitted: (_) => _createCustom(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _createCustom,
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                backgroundColor: AppTokens.brand),
                            child: const Text('Add'),
                          ),
                        ],
                      )
                    : OutlinedButton.icon(
                        onPressed: () => setState(() => _creating = true),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create custom category'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTokens.brand.withValues(alpha: 0.14)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppTokens.brand : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TransactionCategoryStyle.iconOf(label),
                size: 16,
                color: selected ? AppTokens.brand : scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? AppTokens.brand : scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}
