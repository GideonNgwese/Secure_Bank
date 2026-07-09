import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Shown when the user has no budgets at all yet.
class BudgetEmptyState extends StatefulWidget {
  final VoidCallback onCreate;
  const BudgetEmptyState({super.key, required this.onCreate});

  @override
  State<BudgetEmptyState> createState() => _BudgetEmptyStateState();
}

class _BudgetEmptyStateState extends State<BudgetEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550))
    ..forward();
  late final Animation<double> _scale =
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 160,
                      height: 160,
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
                      top: 16,
                      right: 12,
                      child:
                          _chip(Icons.pie_chart_outline, AppTokens.success, 38),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 8,
                      child: _chip(
                          Icons.trending_down_rounded, AppTokens.warning, 34),
                    ),
                    Container(
                      width: 86,
                      height: 86,
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
                      child: const Icon(Icons.account_balance_wallet_outlined,
                          size: 38, color: AppTokens.brand),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Take control of your finances by creating your first budget.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, height: 1.35),
            ),
            const SizedBox(height: 8),
            Text(
              'Set a spending limit per category and SecureBank will track it for you automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: widget.onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTokens.brand,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Create Budget',
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
