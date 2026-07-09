import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/fraud_detection/data/fraud_detection_providers.dart';
import '../../models/fraud_alert_model.dart';
import '../../models/user_model.dart';
import '../services/user_service.dart';

final userServiceProvider = Provider<UserService>((ref) => UserService());

/// Live profile (name + Cloudinary photoUrl) for the given user — the single
/// shared source every header/avatar in the app watches, so there's only
/// ever one `users/{id}` Firestore listener backing the header at a time.
final currentUserProfileProvider =
    StreamProvider.family<AppUser?, String>((ref, userId) {
  return ref.watch(userServiceProvider).streamProfile(userId);
});

/// Combined unread badge count for the header bell — fraud notifications +
/// smart insights + budget alerts, matching exactly what the Notifications
/// screen lists, so the badge number and the feed never disagree.
final headerUnreadCountProvider = Provider.family<int, String>((ref, userId) {
  final budgetAlerts =
      ref.watch(legacyBudgetAlertsProvider(userId)).valueOrNull ??
          const <Map<String, dynamic>>[];
  final int budgetUnread =
      budgetAlerts.where((a) => a['status'] == 'unread').length;
  final int fraudUnread = ref.watch(unreadNotificationCountProvider(userId));
  final int insightUnread = ref.watch(unreadInsightCountProvider(userId));
  return fraudUnread + insightUnread + budgetUnread;
});

enum SecurityStatus { secure, riskDetected }

/// Header shield indicator — flips to [SecurityStatus.riskDetected] when
/// there's an unresolved High/Critical fraud alert, reusing Fraud
/// Detection's own risk vocabulary rather than recomputing risk elsewhere.
final headerSecurityStatusProvider =
    Provider.family<SecurityStatus, String>((ref, userId) {
  final alerts = ref.watch(fraudAlertsProvider(userId)).valueOrNull ??
      const <FraudAlertModel>[];
  final hasOpenHighRisk = alerts.any((a) =>
      a.isUnread && (a.riskLevel == 'High' || a.riskLevel == 'Critical'));
  return hasOpenHighRisk ? SecurityStatus.riskDetected : SecurityStatus.secure;
});

/// 0-100 security score for the Fraud Detection module's header stat —
/// starts at 100 and is pulled down by the average risk score of the
/// user's still-open (unread) fraud alerts. Deliberately distinct from
/// [financialHealthProvider]'s overall score: this one reflects only
/// unresolved fraud risk, not budgeting/income/savings behaviour.
final headerSecurityScoreProvider = Provider.family<int, String>((ref, userId) {
  final alerts = ref.watch(fraudAlertsProvider(userId)).valueOrNull ??
      const <FraudAlertModel>[];
  final open = alerts.where((a) => a.isUnread).toList();
  if (open.isEmpty) return 100;
  final avgRisk = open.fold<int>(0, (s, a) => s + a.riskScore) / open.length;
  return (100 - avgRisk).clamp(0, 100).round();
});
