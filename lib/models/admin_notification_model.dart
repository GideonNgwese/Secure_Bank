/// An admin-authored broadcast — the send-record/audit trail for a message
/// fanned out into the customer-facing `notifications` collection (see
/// `AdminRepository.sendNotification`). Firestore collection:
/// `admin_notifications`. Read/write is admin-only; customers never read
/// this collection directly, only the per-user `notifications` docs it
/// produces.
///
/// [category] deliberately spans BOTH the "Notification Center" types
/// (General Announcement, Security Alert, Fraud Warning, Maintenance
/// Notice, Account Notice) AND the "System Announcements" types (Scheduled
/// maintenance, Application updates, Security notices, Emergency alerts) —
/// those two lists overlap (General Announcement / Maintenance Notice
/// appear in both), so one enum with one fan-out mechanism serves both admin
/// screens instead of duplicating the broadcast machinery twice.
enum AdminNotificationCategory {
  generalAnnouncement,
  securityAlert,
  fraudWarning,
  maintenanceNotice,
  accountNotice,
  appUpdate,
  emergencyAlert,
}

extension AdminNotificationCategoryX on AdminNotificationCategory {
  String get key => switch (this) {
        AdminNotificationCategory.generalAnnouncement => 'general_announcement',
        AdminNotificationCategory.securityAlert => 'security_alert',
        AdminNotificationCategory.fraudWarning => 'fraud_warning',
        AdminNotificationCategory.maintenanceNotice => 'maintenance_notice',
        AdminNotificationCategory.accountNotice => 'account_notice',
        AdminNotificationCategory.appUpdate => 'app_update',
        AdminNotificationCategory.emergencyAlert => 'emergency_alert',
      };

  String get label => switch (this) {
        AdminNotificationCategory.generalAnnouncement => 'General Announcement',
        AdminNotificationCategory.securityAlert => 'Security Alert',
        AdminNotificationCategory.fraudWarning => 'Fraud Warning',
        AdminNotificationCategory.maintenanceNotice => 'Maintenance Notice',
        AdminNotificationCategory.accountNotice => 'Account Notice',
        AdminNotificationCategory.appUpdate => 'Application Update',
        AdminNotificationCategory.emergencyAlert => 'Emergency Alert',
      };

  static AdminNotificationCategory fromKey(String key) => switch (key) {
        'security_alert' => AdminNotificationCategory.securityAlert,
        'fraud_warning' => AdminNotificationCategory.fraudWarning,
        'maintenance_notice' => AdminNotificationCategory.maintenanceNotice,
        'account_notice' => AdminNotificationCategory.accountNotice,
        'app_update' => AdminNotificationCategory.appUpdate,
        'emergency_alert' => AdminNotificationCategory.emergencyAlert,
        _ => AdminNotificationCategory.generalAnnouncement,
      };
}

enum AdminNotificationTarget { single, multiple, all }

extension AdminNotificationTargetX on AdminNotificationTarget {
  String get key => switch (this) {
        AdminNotificationTarget.single => 'single',
        AdminNotificationTarget.multiple => 'multiple',
        AdminNotificationTarget.all => 'all',
      };

  static AdminNotificationTarget fromKey(String key) => switch (key) {
        'multiple' => AdminNotificationTarget.multiple,
        'all' => AdminNotificationTarget.all,
        _ => AdminNotificationTarget.single,
      };
}

class AdminNotificationModel {
  final String id;
  final AdminNotificationCategory category;
  final String title;
  final String body;
  final String priority; // normal / high / critical
  final AdminNotificationTarget targetType;
  final List<String> targetUserIds; // empty when targetType == all
  final String sentBy; // admin uid
  final DateTime createdAt;
  // Engagement (read/acknowledged/replied/resolved) is deliberately NOT
  // stored here as a denormalized counter — that would require every
  // customer client to write back to this admin-owned document, which this
  // app's permission model avoids elsewhere. See [NotificationStats.build]:
  // those figures are computed live from the per-recipient `notifications`
  // docs this send fanned out into.
  final int recipientCount;

  const AdminNotificationModel({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    this.priority = 'normal',
    required this.targetType,
    this.targetUserIds = const [],
    required this.sentBy,
    required this.createdAt,
    this.recipientCount = 0,
  });

  factory AdminNotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return AdminNotificationModel(
      id: id,
      category: AdminNotificationCategoryX.fromKey(map['category'] ?? ''),
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      priority: map['priority'] ?? 'normal',
      targetType: AdminNotificationTargetX.fromKey(map['targetType'] ?? ''),
      targetUserIds: List<String>.from(map['targetUserIds'] ?? const []),
      sentBy: map['sentBy'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      recipientCount: map['recipientCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category.key,
      'title': title,
      'body': body,
      'priority': priority,
      'targetType': targetType.key,
      'targetUserIds': targetUserIds,
      'sentBy': sentBy,
      'createdAt': createdAt.toIso8601String(),
      'recipientCount': recipientCount,
    };
  }
}
