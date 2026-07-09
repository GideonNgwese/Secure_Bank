import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Elegant "no transactions yet" illustration + CTA, shown only when the
/// user truly has zero transactions (not when a search/filter has zero hits
/// — see [TransactionNoMatchesState] for that case).
class TransactionEmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const TransactionEmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTokens.brand.withValues(alpha: 0.10),
                          AppTokens.accent.withValues(alpha: 0.10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 10,
                    child: _chip(Icons.arrow_downward, AppTokens.success, 36),
                  ),
                  Positioned(
                    bottom: 18,
                    left: 6,
                    child: _chip(Icons.arrow_upward, AppTokens.danger, 32),
                  ),
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                      boxShadow: [
                        BoxShadow(
                            color: AppTokens.brand.withValues(alpha: 0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        size: 38, color: AppTokens.brand),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text('No transactions yet.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Record income, expenses, transfers and more to start '
              'tracking your finances.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Your First Transaction',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.16),
          border: const Border.fromBorderSide(
              BorderSide(color: Colors.white, width: 3)),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

class TransactionNoMatchesState extends StatelessWidget {
  const TransactionNoMatchesState({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No transactions match your search or filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
