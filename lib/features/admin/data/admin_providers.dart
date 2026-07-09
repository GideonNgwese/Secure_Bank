import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/domain/auth_user.dart';
import '../../../models/admin_notification_model.dart';
import '../../../models/fraud_alert_model.dart';
import '../../../models/kyc_model.dart';
import '../../../models/notification_model.dart';
import '../../../models/transaction_model.dart';
import '../../../models/user_model.dart';
import 'admin_repository.dart';

final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminRepository());

final adminUsersProvider = StreamProvider<List<AppUser>>(
    (ref) => ref.watch(adminRepositoryProvider).watchAllUsers());

/// Preferred over [adminUsersProvider] for every new Admin Module screen —
/// see [AdminRepository.watchAllAuthUsers].
final adminAuthUsersProvider = StreamProvider<List<AuthUser>>(
    (ref) => ref.watch(adminRepositoryProvider).watchAllAuthUsers());

final adminFlaggedTransactionsProvider = StreamProvider<List<TransactionModel>>(
    (ref) => ref.watch(adminRepositoryProvider).watchFlaggedTransactions());

final adminAllTransactionsProvider = StreamProvider<List<TransactionModel>>(
    (ref) => ref.watch(adminRepositoryProvider).watchAllTransactions());

final adminKycProvider = StreamProvider<List<KycModel>>(
    (ref) => ref.watch(adminRepositoryProvider).watchAllKyc());

final adminActivityLogsProvider = StreamProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(adminRepositoryProvider).watchActivityLogs());

/// All fraud alerts platform-wide, for the Fraud Monitoring Center.
final adminAllFraudAlertsProvider = StreamProvider<List<FraudAlertModel>>(
    (ref) => ref.watch(adminRepositoryProvider).watchAllFraudAlerts());

/// All notifications platform-wide (for [NotificationStats] analytics).
final adminAllNotificationsProvider = StreamProvider<List<NotificationModel>>(
    (ref) => ref.watch(adminRepositoryProvider).watchAllNotifications());

/// Every broadcast the admin has sent (Notification Center + Announcements
/// share this same send-record stream — see [AdminNotificationModel] doc).
final adminNotificationsProvider = StreamProvider<List<AdminNotificationModel>>(
    (ref) => ref.watch(adminRepositoryProvider).watchAdminNotifications());

/// Highest risk level ever recorded for each user, derived from
/// [adminAllFraudAlertsProvider] — the Users Management screen's "Fraud
/// Risk Level" column, without joining raw transaction data.
final adminUserRiskLevelsProvider = Provider<Map<String, String>>((ref) {
  const severity = {'Low': 0, 'Medium': 1, 'High': 2, 'Critical': 3};
  final alerts = ref.watch(adminAllFraudAlertsProvider).valueOrNull ?? [];
  final result = <String, String>{};
  for (final a in alerts) {
    final current = result[a.userId];
    if (current == null ||
        (severity[a.riskLevel] ?? 0) > (severity[current] ?? 0)) {
      result[a.userId] = a.riskLevel;
    }
  }
  return result;
});

final pendingKycCountProvider = Provider<int>((ref) => ref
    .watch(adminKycProvider)
    .valueOrNull
    ?.where((k) => k.status == 'pending')
    .length ??
    0);

final pendingFraudReviewCountProvider = Provider<int>((ref) => ref
    .watch(adminAllFraudAlertsProvider)
    .valueOrNull
    ?.where((a) => a.adminReviewStatus.isEmpty || a.adminReviewStatus == 'under_review')
    .length ??
    0);
