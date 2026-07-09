import '../../../features/auth/domain/auth_user.dart';
import '../../../models/admin_notification_model.dart';
import '../../../models/fraud_alert_model.dart';
import '../../../models/kyc_model.dart';
import '../../../models/notification_model.dart';
import '../../../models/transaction_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';

/// Owns every admin-only read/write — the sole place Admin Module widgets
/// reach Firestore through, instead of each instantiating
/// `FirestoreService()` directly. Wraps [FirestoreService]'s existing admin
/// methods rather than re-implementing them.
class AdminRepository {
  final FirestoreService _fs;
  AdminRepository([FirestoreService? fs]) : _fs = fs ?? FirestoreService();

  Stream<List<AppUser>> watchAllUsers() => _fs.streamAllUsers();

  /// The richer, actively-maintained user view (lastLogin, profileCompleted,
  /// region/city/etc.) — prefer this over [watchAllUsers] for any new
  /// Admin Module screen.
  Stream<List<AuthUser>> watchAllAuthUsers() => _fs.streamAllAuthUsers();

  Future<void> setUserStatus(String userId, String status) =>
      _fs.setUserStatus(userId, status);

  Future<void> setUserActiveStatus({
    required String userId,
    required bool isActive,
    required String adminId,
  }) =>
      _fs.setUserActiveStatus(
          userId: userId, isActive: isActive, adminId: adminId);

  Stream<List<TransactionModel>> watchFlaggedTransactions() =>
      _fs.streamFlaggedTransactions();

  Stream<List<TransactionModel>> watchAllTransactions() =>
      _fs.streamAllTransactions();

  Stream<List<KycModel>> watchAllKyc() => _fs.streamAllKyc();

  Future<void> reviewKyc({
    required String docId,
    required String userId,
    required String status,
    required String reviewedBy,
    String reviewNotes = '',
  }) =>
      _fs.reviewKyc(
        docId: docId,
        userId: userId,
        status: status,
        reviewedBy: reviewedBy,
        reviewNotes: reviewNotes,
      );

  Stream<List<Map<String, dynamic>>> watchActivityLogs() =>
      _fs.streamActivityLogs();

  // ---------------- Fraud Monitoring Center ----------------

  Stream<List<FraudAlertModel>> watchAllFraudAlerts() =>
      _fs.streamAllFraudAlerts();

  /// All notifications platform-wide, for [NotificationStats] analytics.
  Stream<List<NotificationModel>> watchAllNotifications() =>
      _fs.streamAllNotifications();

  Future<void> updateFraudAlertAdminReview({
    required String alertId,
    required String adminReviewStatus,
    required String adminId,
    String note = '',
  }) =>
      _fs.updateFraudAlertAdminReview(
        alertId: alertId,
        adminReviewStatus: adminReviewStatus,
        adminId: adminId,
        note: note,
      );

  // ---------------- Notification Center / Announcements ----------------

  Stream<List<AdminNotificationModel>> watchAdminNotifications() =>
      _fs.streamAdminNotifications();

  Future<AdminNotificationModel> sendNotification({
    required AdminNotificationCategory category,
    required String title,
    required String body,
    String priority = 'normal',
    required AdminNotificationTarget targetType,
    List<String> targetUserIds = const [],
    required List<String> allUserIds,
    required String adminId,
  }) =>
      _fs.sendAdminNotification(
        category: category,
        title: title,
        body: body,
        priority: priority,
        targetType: targetType,
        targetUserIds: targetUserIds,
        allUserIds: allUserIds,
        adminId: adminId,
      );
}
