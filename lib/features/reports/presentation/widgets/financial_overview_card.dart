import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/constants.dart';
import '../../domain/report_summary.dart';

/// The premium "Financial Overview Card" — Income/Expenses/Savings/Balance
/// with count-up animations, plus a compact circular Financial Health Score.
class FinancialOverviewCard extends StatelessWidget {
  final ReportSummary summary;
  const FinancialOverviewCard({super.key, required this.summary});

  Color get _healthColor => switch (summary.health.label) {
        'Excellent' => AppTokens.success,
        'Good' => Colors.white,
        'Fair' => AppTokens.warning,
        _ => AppTokens.warning,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1B3D), AppTokens.brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0A1B3D).withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current balance',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    _countUp(summary.currentBalance, fontSize: 28),
                  ],
                ),
              ),
              _healthRing(),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _miniStat('Income', summary.totalIncome, Icons.south_west_rounded,
                  const Color(0xFF4ADE80)),
              _divider(),
              _miniStat('Expenses', summary.totalExpense,
                  Icons.north_east_rounded, const Color(0xFFFF8A8A)),
              _divider(),
              _miniStat('Savings', summary.savings, Icons.savings_outlined,
                  const Color(0xFF9BD1FF)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _healthRing() {
    final score = summary.health.score;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => SizedBox(
        width: 66,
        height: 66,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 66,
              height: 66,
              child: CircularProgressIndicator(
                value: t,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: _healthColor,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(t * 100).round()}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const Text('score',
                    style: TextStyle(color: Colors.white60, fontSize: 8)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _countUp(double value, {required double fontSize}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(formatFCFA(v),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 34, color: Colors.white.withValues(alpha: 0.14));

  Widget _miniStat(String label, double value, IconData icon, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 10.5)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(formatFCFA(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
