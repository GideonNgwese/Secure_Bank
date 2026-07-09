import 'package:flutter/material.dart';

import '../../../utils/constants.dart';

/// The four risk tiers used across the Fraud Detection module. Persisted as
/// plain strings on both `TransactionModel.riskLevel` and `fraud_alerts`
/// docs (see [label]) so this stays a display/behavior helper, not a schema
/// change to existing data.
///
/// Note: intentionally NOT called `name` — `enum` already has a built-in
/// `.name` getter (lowercase, e.g. `'low'`) that a same-named extension
/// member cannot override via normal dot-syntax; using that name here would
/// silently resolve to the wrong (lowercase) string everywhere.
enum RiskLevel { low, medium, high, critical }

extension RiskLevelX on RiskLevel {
  String get label => switch (this) {
        RiskLevel.low => 'Low',
        RiskLevel.medium => 'Medium',
        RiskLevel.high => 'High',
        RiskLevel.critical => 'Critical',
      };

  Color get color => riskColor(label);

  IconData get icon => switch (this) {
        RiskLevel.low => Icons.check_circle_outline,
        RiskLevel.medium => Icons.info_outline,
        RiskLevel.high => Icons.warning_amber_rounded,
        RiskLevel.critical => Icons.dangerous_outlined,
      };

  static RiskLevel fromScore(int score) {
    if (score >= 76) return RiskLevel.critical;
    if (score >= 51) return RiskLevel.high;
    if (score >= 26) return RiskLevel.medium;
    return RiskLevel.low;
  }

  static RiskLevel fromName(String name) => switch (name) {
        'Critical' => RiskLevel.critical,
        'High' => RiskLevel.high,
        'Medium' => RiskLevel.medium,
        _ => RiskLevel.low,
      };
}

/// The single, central place SecureBank's flat FCFA risk bands are defined —
/// change a threshold here and every screen/rule picks it up. Nothing else
/// should hardcode these numbers.
///
/// LOW: 0 – 70,000 · MEDIUM: 70,001 – 99,999 · HIGH: 100,000 – 499,999 ·
/// CRITICAL: 500,000 and above. Colors come from [RiskLevelX.color]
/// (→ `riskColor()` in utils/constants.dart), already Blue/Orange/Red/Dark
/// red for these four levels — no separate color config needed here.
class RiskThresholds {
  RiskThresholds._();

  static const double mediumMin = 70001;
  static const double highMin = 100000;
  static const double criticalMin = 500000;

  static RiskLevel levelForAmount(double amount) {
    if (amount >= criticalMin) return RiskLevel.critical;
    if (amount >= highMin) return RiskLevel.high;
    if (amount >= mediumMin) return RiskLevel.medium;
    return RiskLevel.low;
  }

  /// A score that, once run through [RiskLevelX.fromScore], reproduces
  /// exactly [levelForAmount] for the same amount — the one place amount-
  /// based and rule-score-based classification are reconciled, so a
  /// transaction's final `riskScore`/`riskLevel` never disagree with each
  /// other. The fraud engine takes the max of this and the summed
  /// behavioral rule score, so a large amount alone guarantees its band's
  /// level regardless of what any individual rule's point value is tuned to.
  static int nominalScoreForAmount(double amount) =>
      switch (levelForAmount(amount)) {
        RiskLevel.critical => 76,
        RiskLevel.high => 51,
        RiskLevel.medium => 26,
        RiskLevel.low => 0,
      };
}
