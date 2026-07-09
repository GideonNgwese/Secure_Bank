import '../../../features/auth/domain/auth_user.dart';
import '../../../models/fraud_alert_model.dart';
import '../../../models/kyc_model.dart';
import '../../../models/notification_model.dart';

/// Platform-wide counters for the Admin Dashboard's stat row + the
/// Analytics screen's summary cards — computed client-side from the same
/// live streams the rest of the Admin Module already watches (no separate
/// aggregation collection/Cloud Function; this app has none, and these
/// counts are cheap over its current data volume).
class AdminOverviewStats {
  final int totalUsers;
  final int activeUsersToday;
  final int newRegistrationsToday;
  final int fraudAlertsToday;
  final int pendingFraudReviews;
  final int pendingKycReviews;
  final int weeklyActiveUsers;

  const AdminOverviewStats({
    required this.totalUsers,
    required this.activeUsersToday,
    required this.newRegistrationsToday,
    required this.fraudAlertsToday,
    required this.pendingFraudReviews,
    required this.pendingKycReviews,
    required this.weeklyActiveUsers,
  });

  static bool _isToday(DateTime? d, DateTime now) =>
      d != null && d.year == now.year && d.month == now.month && d.day == now.day;

  factory AdminOverviewStats.build({
    required List<AuthUser> users,
    required List<FraudAlertModel> alerts,
    required List<KycModel> kyc,
    required DateTime now,
  }) {
    final customers = users.where((u) => !u.isAdmin).toList();
    final weekAgo = now.subtract(const Duration(days: 7));
    return AdminOverviewStats(
      totalUsers: customers.length,
      activeUsersToday:
          customers.where((u) => _isToday(u.lastLogin, now)).length,
      newRegistrationsToday:
          customers.where((u) => _isToday(u.createdAt, now)).length,
      fraudAlertsToday: alerts.where((a) => _isToday(a.createdAt, now)).length,
      pendingFraudReviews: alerts
          .where((a) =>
              a.adminReviewStatus.isEmpty ||
              a.adminReviewStatus == 'under_review')
          .length,
      pendingKycReviews: kyc.where((k) => k.status == 'pending').length,
      weeklyActiveUsers: customers
          .where((u) => u.lastLogin != null && u.lastLogin!.isAfter(weekAgo))
          .length,
    );
  }
}

/// KYC approval-rate breakdown for the Analytics screen.
class KycStats {
  final int approved;
  final int rejected;
  final int pending;
  const KycStats(
      {required this.approved, required this.rejected, required this.pending});

  int get reviewed => approved + rejected;
  double get approvalRatePct => reviewed == 0 ? 0 : approved / reviewed * 100;

  factory KycStats.build(List<KycModel> kyc) => KycStats(
        approved: kyc.where((k) => k.status == 'approved').length,
        rejected: kyc.where((k) => k.status == 'rejected').length,
        pending: kyc.where((k) => k.status == 'pending').length,
      );
}

/// Notification delivery/engagement analytics — computed directly from the
/// per-recipient `notifications` docs an admin broadcast fanned out into
/// (filtered to `adminNotificationId.isNotEmpty`), not from a denormalized
/// counter on the send-record: a counter would need every customer client to
/// write back to an admin-owned document to stay accurate, which is exactly
/// the kind of cross-permission complexity this app's rules deliberately
/// avoid elsewhere. Scanning the live per-recipient docs is simpler and
/// always correct.
///
/// `delivered` is reported as equal to `sent` — this is a realtime
/// Firestore-synced inbox with no separate push/FCM layer, so there's no
/// observable "sent but not yet delivered" state to measure; showing a
/// fabricated lower number would be less honest than reporting delivery as
/// complete once written.
class NotificationStats {
  final int sent;
  final int read;
  final int acknowledged;
  final int replied;
  final int resolved;
  const NotificationStats({
    required this.sent,
    required this.read,
    required this.acknowledged,
    required this.replied,
    required this.resolved,
  });

  int get delivered => sent;
  double get readRatePct => sent == 0 ? 0 : read / sent * 100;
  double get responseRatePct =>
      sent == 0 ? 0 : (acknowledged + replied) / sent * 100;

  factory NotificationStats.build(List<NotificationModel> adminSent) {
    return NotificationStats(
      sent: adminSent.length,
      read: adminSent.where((n) => n.read).length,
      acknowledged: adminSent.where((n) => n.status == 'acknowledged').length,
      replied: adminSent.where((n) => n.status == 'replied').length,
      resolved: adminSent.where((n) => n.status == 'resolved').length,
    );
  }
}
