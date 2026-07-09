import '../../../models/financial_insight_model.dart';
import '../../../models/notification_model.dart';

enum NotificationKind { fraud, insight, budget }

/// A unified, read-only view over the three sources that make up this app's
/// notifications — the real `notifications` collection (fraud alerts),
/// `financial_insights`, and the generic `alerts` collection's budget
/// entries — so the feed reads as one inbox.
class NotificationItem {
  final String id;
  final NotificationKind kind;
  final bool isUnread;
  final bool isDismissed;
  final DateTime createdAt;
  final NotificationModel? notification;
  final FinancialInsightModel? insight;
  final Map<String, dynamic>? budgetAlert;

  const NotificationItem._({
    required this.id,
    required this.kind,
    required this.isUnread,
    required this.isDismissed,
    required this.createdAt,
    this.notification,
    this.insight,
    this.budgetAlert,
  });

  factory NotificationItem.fromNotification(NotificationModel n) =>
      NotificationItem._(
        id: n.id,
        kind: NotificationKind.fraud,
        isUnread: !n.read,
        isDismissed: n.dismissed,
        createdAt: n.createdAt,
        notification: n,
      );

  factory NotificationItem.fromInsight(FinancialInsightModel i) =>
      NotificationItem._(
        id: i.id,
        kind: NotificationKind.insight,
        isUnread: i.isUnread,
        isDismissed: i.status == 'dismissed',
        createdAt: i.createdAt,
        insight: i,
      );

  factory NotificationItem.fromBudgetAlert(Map<String, dynamic> m) {
    final status = m['status'] as String? ?? 'unread';
    return NotificationItem._(
      id: m['id'] as String,
      kind: NotificationKind.budget,
      isUnread: status == 'unread',
      isDismissed: status == 'dismissed',
      createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
      budgetAlert: m,
    );
  }

  /// Merges and sorts the three sources newest-first, dropping anything
  /// already dismissed — the Notifications feed is an actionable inbox, not
  /// an audit log (Fraud Center's timeline still shows dismissed items,
  /// dimmed, for that purpose).
  static List<NotificationItem> build({
    required List<NotificationModel> notifications,
    required List<FinancialInsightModel> insights,
    required List<Map<String, dynamic>> budgetAlerts,
  }) {
    final items = <NotificationItem>[
      ...notifications.map(NotificationItem.fromNotification),
      ...insights.map(NotificationItem.fromInsight),
      ...budgetAlerts.map(NotificationItem.fromBudgetAlert),
    ].where((n) => !n.isDismissed).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}
