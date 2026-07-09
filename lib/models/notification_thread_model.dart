/// A lightweight, bounded conversation thread anchored to ONE notification:
/// Notification -> Customer Reply -> Admin Reply -> ... -> Resolved. This is
/// NOT a general chat feature — see [kMaxThreadMessages]. Firestore
/// collection: `notification_threads`, doc id == the originating
/// notificationId (one thread per notification, upserted).
const kMaxThreadMessages = 10;

enum ThreadStatus { open, pending, resolved, closed }

extension ThreadStatusX on ThreadStatus {
  String get key => switch (this) {
        ThreadStatus.open => 'open',
        ThreadStatus.pending => 'pending',
        ThreadStatus.resolved => 'resolved',
        ThreadStatus.closed => 'closed',
      };

  String get label => switch (this) {
        ThreadStatus.open => 'Open',
        ThreadStatus.pending => 'Pending',
        ThreadStatus.resolved => 'Resolved',
        ThreadStatus.closed => 'Closed',
      };

  static ThreadStatus fromKey(String key) => switch (key) {
        'pending' => ThreadStatus.pending,
        'resolved' => ThreadStatus.resolved,
        'closed' => ThreadStatus.closed,
        _ => ThreadStatus.open,
      };
}

/// Which admin-facing filter bucket a thread falls into — derived from the
/// originating notification's category at thread-creation time.
enum ThreadCategory { security, fraud, general }

extension ThreadCategoryX on ThreadCategory {
  String get key => switch (this) {
        ThreadCategory.security => 'security',
        ThreadCategory.fraud => 'fraud',
        ThreadCategory.general => 'general',
      };

  String get label => switch (this) {
        ThreadCategory.security => 'Security',
        ThreadCategory.fraud => 'Fraud',
        ThreadCategory.general => 'General',
      };

  static ThreadCategory fromKey(String key) => switch (key) {
        'security' => ThreadCategory.security,
        'fraud' => ThreadCategory.fraud,
        _ => ThreadCategory.general,
      };

  /// Buckets a notification's `type` (admin broadcast category key, or the
  /// fraud engine's own `'fraud_alert'`) into the coarser filter used here.
  static ThreadCategory fromNotificationType(String type) => switch (type) {
        'security_alert' || 'emergency_alert' => ThreadCategory.security,
        'fraud_warning' || 'fraud_alert' => ThreadCategory.fraud,
        _ => ThreadCategory.general,
      };
}

class NotificationThreadModel {
  final String id; // == notificationId
  final String notificationId;
  final String userId;
  final String userName;
  final String userEmail;
  final String title; // mirrors the originating notification's title
  final ThreadCategory category;
  final String priority;
  final ThreadStatus status;
  final bool pinned;
  final int messageCount;
  final DateTime lastMessageAt;
  final String lastMessagePreview;
  final String lastSenderRole;
  // Set true for the OTHER party whenever a message is sent, cleared when
  // that party opens the thread (SupportRepository.markRead) — a cheap,
  // thread-level flag so list/badge views don't need to scan every
  // thread's messages just to know who has something unread.
  final bool adminUnread;
  final bool customerUnread;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationThreadModel({
    required this.id,
    required this.notificationId,
    required this.userId,
    this.userName = '',
    this.userEmail = '',
    required this.title,
    this.category = ThreadCategory.general,
    this.priority = 'normal',
    this.status = ThreadStatus.open,
    this.pinned = false,
    this.messageCount = 0,
    required this.lastMessageAt,
    this.lastMessagePreview = '',
    this.lastSenderRole = 'customer',
    this.adminUnread = false,
    this.customerUnread = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get atMessageLimit => messageCount >= kMaxThreadMessages;

  factory NotificationThreadModel.fromMap(
      String id, Map<String, dynamic> map) {
    return NotificationThreadModel(
      id: id,
      notificationId: map['notificationId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      title: map['title'] ?? '',
      category: ThreadCategoryX.fromKey(map['category'] ?? ''),
      priority: map['priority'] ?? 'normal',
      status: ThreadStatusX.fromKey(map['status'] ?? ''),
      pinned: map['pinned'] ?? false,
      messageCount: map['messageCount'] ?? 0,
      lastMessageAt:
          DateTime.tryParse(map['lastMessageAt'] ?? '') ?? DateTime.now(),
      lastMessagePreview: map['lastMessagePreview'] ?? '',
      lastSenderRole: map['lastSenderRole'] ?? 'customer',
      adminUnread: map['adminUnread'] ?? false,
      customerUnread: map['customerUnread'] ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'title': title,
      'category': category.key,
      'priority': priority,
      'status': status.key,
      'pinned': pinned,
      'messageCount': messageCount,
      'lastMessageAt': lastMessageAt.toIso8601String(),
      'lastMessagePreview': lastMessagePreview,
      'lastSenderRole': lastSenderRole,
      'adminUnread': adminUnread,
      'customerUnread': customerUnread,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
