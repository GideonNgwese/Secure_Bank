/// A durable, user-facing notification record. Firestore collection:
/// `notifications`. Auto-created whenever a fraud alert is generated (see
/// `FraudDetectionRepository.recordAlert`) — this is the app's real
/// notification log, separate from the richer domain collections
/// (`fraud_alerts`, `financial_insights`) those alerts/insights themselves
/// live in, so a future push-notification integration has one simple place
/// to watch.
class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // e.g. 'fraud_alert'
  final bool read;
  final DateTime createdAt;

  // Extra payload carried alongside the required fields above so the
  // Notifications feed can render the same rich fraud-alert card it always
  // has, without a second read of `fraud_alerts` for the same event.
  final String transactionId;
  final String riskLevel;
  final int riskScore;
  final String recommendation;
  // Swipe-to-dismiss removes a notification from the feed without deleting
  // it (Firestore rules disallow delete here, same as fraud_alerts/alerts,
  // to preserve the audit trail) — a dedicated flag since `read` alone can't
  // tell "seen" apart from "dismissed."
  final bool dismissed;
  // Fraud Review Workflow: marks a notification that needs the user to act
  // (vs. just informational) and what that action is, so the Notifications
  // feed can render "Review Now" / "Dismiss" buttons. `transactionId` above
  // already serves as the linked-transaction reference — no separate field.
  final bool actionRequired;
  final String actionType; // e.g. 'review_transaction'
  // Admin Notification Center / Announcements: lets an admin broadcast into
  // this same collection instead of a parallel one. `adminNotificationId`
  // links back to the `admin_notifications` send-record (for delivery/read/
  // response analytics); empty for fraud-sourced notifications. `priority`
  // and `status` progress sent -> read -> acknowledged/replied -> resolved
  // (see SupportResponseModel) purely for the admin's own tracking — customer
  // rendering doesn't branch on them.
  final String adminNotificationId;
  final String priority; // normal / high / critical
  final String status; // sent / read / acknowledged / replied / resolved

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.read = false,
    required this.createdAt,
    this.transactionId = '',
    this.riskLevel = '',
    this.riskScore = 0,
    this.recommendation = '',
    this.dismissed = false,
    this.actionRequired = false,
    this.actionType = '',
    this.adminNotificationId = '',
    this.priority = 'normal',
    this.status = 'sent',
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return NotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? '',
      read: map['read'] ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      transactionId: map['transactionId'] ?? '',
      riskLevel: map['riskLevel'] ?? '',
      riskScore: (map['riskScore'] ?? 0) is int
          ? map['riskScore'] ?? 0
          : (map['riskScore'] as num).toInt(),
      recommendation: map['recommendation'] ?? '',
      dismissed: map['dismissed'] ?? false,
      actionRequired: map['actionRequired'] ?? false,
      actionType: map['actionType'] ?? '',
      adminNotificationId: map['adminNotificationId'] ?? '',
      priority: map['priority'] ?? 'normal',
      status: map['status'] ?? 'sent',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'read': read,
      'createdAt': createdAt.toIso8601String(),
      'transactionId': transactionId,
      'riskLevel': riskLevel,
      'riskScore': riskScore,
      'recommendation': recommendation,
      'dismissed': dismissed,
      'actionRequired': actionRequired,
      'actionType': actionType,
      'adminNotificationId': adminNotificationId,
      'priority': priority,
      'status': status,
    };
  }
}
