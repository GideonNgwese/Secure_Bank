import '../../../models/fraud_alert_model.dart';
import '../../../models/transaction_model.dart';

class FraudSummary {
  final int totalAlerts;
  final int lowCount;
  final int mediumCount;
  final int highCount;
  final int criticalCount;
  final int resolvedCount; // status read or dismissed — i.e. acknowledged
  final int suspiciousTransactionCount; // transactions with riskLevel != Low

  const FraudSummary({
    required this.totalAlerts,
    required this.lowCount,
    required this.mediumCount,
    required this.highCount,
    required this.criticalCount,
    required this.resolvedCount,
    required this.suspiciousTransactionCount,
  });

  int get openCount => totalAlerts - resolvedCount;

  static FraudSummary build({
    required List<FraudAlertModel> alertsInRange,
    required List<TransactionModel> txInRange,
  }) {
    var low = 0, med = 0, high = 0, crit = 0, resolved = 0;
    for (final a in alertsInRange) {
      switch (a.riskLevel) {
        case 'Critical':
          crit++;
        case 'High':
          high++;
        case 'Medium':
          med++;
        default:
          low++;
      }
      if (a.status != 'unread') resolved++;
    }
    final suspicious = txInRange.where((t) => t.riskLevel != 'Low').length;

    return FraudSummary(
      totalAlerts: alertsInRange.length,
      lowCount: low,
      mediumCount: med,
      highCount: high,
      criticalCount: crit,
      resolvedCount: resolved,
      suspiciousTransactionCount: suspicious,
    );
  }
}
