import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../utils/constants.dart';
import '../../domain/risk_level.dart';

/// Fraud Rule Tester — lets a developer verify amount-band classification
/// against the exact thresholds `RiskThresholds` is configured with, without
/// writing a single real transaction to Firestore. Only reachable when
/// `AppConfig.fraudTestModeEnabled` is true (Settings → Developer).
///
/// The multi-transaction rules (rapid-fire, daily frequency, budget
/// overspending, duplicate merchant) genuinely need real transaction history
/// to evaluate — faking that here would either write throwaway data into
/// real analytics or duplicate the whole rule engine's logic a second time.
/// Instead this screen documents the manual steps to trigger each one for
/// real, using the actual transaction form.
class FraudTestModeScreen extends StatefulWidget {
  const FraudTestModeScreen({super.key});

  @override
  State<FraudTestModeScreen> createState() => _FraudTestModeScreenState();
}

class _FraudTestModeScreenState extends State<FraudTestModeScreen> {
  final _amountController = TextEditingController(text: '50000');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text) ?? 0;

  void _setAmount(double v) =>
      setState(() => _amountController.text = v.toStringAsFixed(0));

  @override
  Widget build(BuildContext context) {
    final level = RiskThresholds.levelForAmount(_amount);

    return Scaffold(
      appBar: AppBar(title: const Text('Fraud Rule Tester')),
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
              'Developer tool — classifies an amount against the live '
              'RiskThresholds config below. Nothing here writes to '
              'Firestore.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 18),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Transaction amount (FCFA)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _quickFill('50,000 → Low', 50000),
              _quickFill('85,000 → Medium', 85000),
              _quickFill('150,000 → High', 150000),
              _quickFill('700,000 → Critical', 700000),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: level.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: level.color.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(level.icon, color: level.color, size: 28),
                    const SizedBox(width: 12),
                    Text('${level.label} Risk',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: level.color)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatFCFA(_amount),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Configured bands (RiskThresholds)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          _bandRow('Low', '0 – 70,000 FCFA', RiskLevel.low),
          _bandRow(
              'Medium',
              '70,001 – ${(RiskThresholds.highMin - 1).toStringAsFixed(0)} FCFA',
              RiskLevel.medium),
          _bandRow(
              'High',
              '${RiskThresholds.highMin.toStringAsFixed(0)} – '
                  '${(RiskThresholds.criticalMin - 1).toStringAsFixed(0)} FCFA',
              RiskLevel.high),
          _bandRow(
              'Critical',
              '${RiskThresholds.criticalMin.toStringAsFixed(0)}+ FCFA',
              RiskLevel.critical),
          const SizedBox(height: 28),
          const Text('Testing the other rules',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          const Text(
            'These need real transaction history, so trigger them from the '
            'actual Add Transaction form and watch Notifications:\n\n'
            '• Rapid Transaction Activity — add 6 transactions of any type '
            'within 60 seconds.\n'
            '• High Spending Frequency — add more than 10 transactions in '
            'one day.\n'
            '• Budget Overspending — add an expense that pushes an active '
            'budget over 100%.\n'
            '• Duplicate Merchant Activity — add 4 payments to the same '
            'merchant within 48 hours.\n'
            '• Balance Warning — add an expense larger than the account\'s '
            'current balance.',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _quickFill(String label, double amount) {
    return OutlinedButton(
      onPressed: () => _setAmount(amount),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _bandRow(String label, String range, RiskLevel level) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: level.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 70, child: Text(label)),
          Expanded(
              child: Text(range,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted))),
        ],
      ),
    );
  }
}
