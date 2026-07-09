import 'package:flutter/material.dart';
import '../../../../utils/constants.dart';

/// Elegant "no accounts yet" illustration + CTA, shown only when the user
/// truly has zero account profiles (not when a search/filter has zero hits).
class AccountEmptyState extends StatelessWidget {
  final VoidCallback onAddAccount;
  const AccountEmptyState({super.key, required this.onAddAccount});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Illustration(),
            const SizedBox(height: 28),
            const Text(
              'No financial accounts yet.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a bank, mobile money, or cash profile to start tracking '
              'balances — no banking login required.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: onAddAccount,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Your First Account',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
                  AppColors.primary.withValues(alpha: 0.10),
                  AppColors.accent.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: 8,
            child: _chip(Icons.smartphone, AppColors.accent, 40),
          ),
          Positioned(
            bottom: 22,
            right: 4,
            child: _chip(Icons.payments_outlined, AppColors.success, 36),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12)),
              ],
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                size: 40, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
