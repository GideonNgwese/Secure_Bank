import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A single metric tile for the Admin Dashboard/Analytics stat grids —
/// enterprise-console styling (Stripe/Azure-like): icon chip, big number,
/// muted label, optional trend caption.
class AdminStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : scheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  if (onTap != null)
                    Icon(Icons.arrow_outward_rounded,
                        size: 14, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(caption!,
                    style: TextStyle(fontSize: 10.5, color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps a set of [AdminStatCard]s in a responsive grid — 2 columns on
/// phones, more on wider admin-console layouts.
///
/// Uses a fixed [mainAxisExtent] rather than `childAspectRatio`: an aspect
/// ratio derives the cell height from the cell WIDTH, so on narrower phones
/// (2 columns) the cell got too short to fit the icon + value + label +
/// optional caption stack, causing a bottom overflow. A fixed height is
/// immune to that — it fits the tallest card variant regardless of screen
/// width.
class AdminStatGrid extends StatelessWidget {
  final List<Widget> cards;
  const AdminStatGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100 ? 4 : (width >= 700 ? 3 : 2);
    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // 148 measured 21px short on the caption variant (New
        // Registrations / Fraud Alerts, both showing "today") — that's
        // 169px actually needed. Using 184 rather than just covering the
        // measured gap, so device/font-scale variance doesn't reopen this.
        mainAxisExtent: 184,
      ),
      itemBuilder: (context, i) => cards[i],
    );
  }
}
