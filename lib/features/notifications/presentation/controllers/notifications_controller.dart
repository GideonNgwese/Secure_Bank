import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/firestore_service.dart';
import '../../../fraud_detection/data/fraud_detection_providers.dart';
import '../../domain/notification_item.dart';

final _notificationsFirestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

/// Drives the Notifications screen's mutations. Reuses
/// [FraudDetectionRepository] for fraud/insight items and [FirestoreService]
/// for budget-alert items — the same repositories that already own those
/// three collections elsewhere in the app, so read/dismiss logic never
/// diverges between Notifications and Fraud Center.
class NotificationsController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> markRead(NotificationItem item) async {
    switch (item.kind) {
      case NotificationKind.fraud:
        await ref
            .read(fraudDetectionRepositoryProvider)
            .setNotificationStatus(item.id, read: true, alertStatus: 'read');
      case NotificationKind.insight:
        await ref
            .read(fraudDetectionRepositoryProvider)
            .setInsightStatus(item.id, 'read');
      case NotificationKind.budget:
        await ref
            .read(_notificationsFirestoreServiceProvider)
            .markAlertRead(item.id);
    }
  }

  /// "Delete" from the user's point of view — the underlying Firestore
  /// rules deliberately disallow a true delete on these collections so the
  /// fraud/insight audit trail is preserved, so this dismisses instead,
  /// which drops it out of [notificationFeedProvider].
  Future<void> dismiss(NotificationItem item) async {
    switch (item.kind) {
      case NotificationKind.fraud:
        await ref.read(fraudDetectionRepositoryProvider).setNotificationStatus(
            item.id,
            dismissed: true,
            alertStatus: 'dismissed');
      case NotificationKind.insight:
        await ref
            .read(fraudDetectionRepositoryProvider)
            .setInsightStatus(item.id, 'dismissed');
      case NotificationKind.budget:
        await ref
            .read(_notificationsFirestoreServiceProvider)
            .dismissAlert(item.id);
    }
  }

  Future<void> markAllRead(String userId) async {
    await Future.wait([
      ref
          .read(fraudDetectionRepositoryProvider)
          .markAllNotificationsRead(userId),
      ref.read(fraudDetectionRepositoryProvider).markAllInsightsRead(userId),
      ref
          .read(_notificationsFirestoreServiceProvider)
          .markAllAlertsRead(userId),
    ]);
  }
}

final notificationsControllerProvider =
    AutoDisposeAsyncNotifierProvider<NotificationsController, void>(
        NotificationsController.new);
