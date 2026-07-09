import 'package:flutter/material.dart';
import '../../../../utils/constants.dart';

/// Premium gradient header showing the total across active accounts.
/// Mirrors the dashboard balance card so the accounts tab feels part of the
/// same product, not a bolted-on screen.
class AccountSummaryHeader extends StatelessWidget {
  final double total;
  final int accountCount;
  final bool hidden;
  final VoidCallback onToggleHidden;

  const AccountSummaryHeader({
    super.key,
    required this.total,
    required this.accountCount,
    required this.hidden,
    required this.onToggleHidden,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.32),
              blurRadius: 20,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total across active accounts',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                hidden
                    ? const Text('••••••••',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2))
                    : TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: total),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Text(formatFCFA(v),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ),
                const SizedBox(height: 4),
                Text(
                    '$accountCount ${accountCount == 1 ? 'account' : 'accounts'}',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          _IconButton(
            icon: hidden ? Icons.visibility_off : Icons.visibility,
            onTap: onToggleHidden,
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}
