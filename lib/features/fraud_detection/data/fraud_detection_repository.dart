import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/financial_insight_model.dart';
import '../../../models/fraud_alert_model.dart';
import '../../../models/notification_model.dart';
import '../domain/smart_insights.dart';

/// Owns the `fraud_alerts`, `notifications`, and `financial_insights`
/// collections. Used both by the presentation layer (streams, mark
/// read/dismiss) and by [FraudAnalysisService] (writing a new alert — and
/// its paired notification — the moment a risky transaction is scored).
class FraudDetectionRepository {
  final FirebaseFirestore _db;
  FraudDetectionRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  // ---------------- Fraud alerts ----------------

  Stream<List<FraudAlertModel>> watchAlerts(String userId) {
    return _db
        .collection('fraud_alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => FraudAlertModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Upserts one alert per transaction (deterministic doc ID = transactionId)
  /// instead of always creating a new doc — re-scoring the same transaction
  /// (e.g. the user edits it again while it's still risky) updates the risk
  /// fields in place rather than spamming duplicate alerts. `status`/
  /// `createdAt` are preserved on an existing doc so a transaction the user
  /// already read/dismissed isn't resurrected as unread just because it was
  /// re-scored.
  Future<void> recordAlert(FraudAlertModel alert) async {
    final ref = _db.collection('fraud_alerts').doc(alert.transactionId);
    final existing = await ref.get();
    if (existing.exists) {
      await ref.update({
        'riskScore': alert.riskScore,
        'riskLevel': alert.riskLevel,
        'reason': alert.reason,
        'recommendation': alert.recommendation,
      });
    } else {
      await ref.set(alert.toMap());
      // "Whenever a fraud alert is created, automatically create a
      // notification" — only on first creation, not on every re-score, so
      // re-editing a still-risky transaction doesn't spam duplicate
      // notifications for the same underlying alert.
      await _createNotification(NotificationModel(
        id: '',
        userId: alert.userId,
        title: alert.reviewRequired
            ? '${alert.riskLevel} Risk Transaction'
            : '${alert.riskLevel} Risk Alert',
        body: alert.reviewRequired
            ? '${alert.reason} Pending your approval.'
            : alert.reason,
        type: 'fraud_alert',
        createdAt: alert.createdAt,
        transactionId: alert.transactionId,
        riskLevel: alert.riskLevel,
        riskScore: alert.riskScore,
        recommendation: alert.recommendation,
        actionRequired: alert.reviewRequired,
        actionType: alert.reviewRequired ? 'review_transaction' : '',
      ));
    }
  }

  // ---------------- Notifications ----------------

  /// Same deterministic-ID-per-transaction pattern as `fraud_alerts` (see
  /// [recordAlert]) so the notification and its underlying alert always
  /// share one id and can be kept in sync (e.g. marking one read).
  Future<void> _createNotification(NotificationModel notification) {
    return _db
        .collection('notifications')
        .doc(notification.transactionId)
        .set(notification.toMap());
  }

  Stream<List<NotificationModel>> watchNotifications(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => NotificationModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Marks both the notification and its underlying fraud alert read/
  /// dismissed together (same id, see [_createNotification]) so Notification
  /// Center and Fraud Center never disagree about the same event's status.
  Future<void> setNotificationStatus(String id,
      {bool? read, bool? dismissed, String? alertStatus}) async {
    final patch = <String, dynamic>{
      if (read != null) 'read': read,
      if (dismissed != null) 'dismissed': dismissed,
    };
    final batch = _db.batch();
    if (patch.isNotEmpty) {
      batch.update(_db.collection('notifications').doc(id), patch);
    }
    if (alertStatus != null) {
      batch.update(
          _db.collection('fraud_alerts').doc(id), {'status': alertStatus});
    }
    await batch.commit();
  }

  /// Resolves a `fraud_alerts` doc and clears its paired notification's
  /// action-required flag together (same shared id, see [_createNotification])
  /// — the Fraud Review Workflow's Approve/Decline actions call this after
  /// updating the transaction itself.
  Future<void> resolveAlert(
    String id, {
    required String alertStatus, // 'approved' / 'confirmed_fraud'
    required String resolution,
  }) async {
    final now = DateTime.now().toIso8601String();
    final batch = _db.batch();
    batch.update(_db.collection('fraud_alerts').doc(id), {
      'status': alertStatus,
      'resolvedAt': now,
      'resolution': resolution,
    });
    batch.update(_db.collection('notifications').doc(id), {
      'read': true,
      'actionRequired': false,
    });
    await batch.commit();
  }

  /// The extra "your transaction has been blocked" security notification
  /// generated on Decline — separate doc from the original alert
  /// notification (which [resolveAlert] already resolved above).
  Future<void> createSecurityBlockNotification({
    required String userId,
    required String transactionId,
  }) {
    final ref = _db.collection('notifications').doc();
    return ref.set(NotificationModel(
      id: ref.id,
      userId: userId,
      title: 'Transaction Blocked',
      body: 'Your transaction has been blocked for your protection.',
      type: 'security_block',
      createdAt: DateTime.now(),
      transactionId: transactionId,
    ).toMap());
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final snap = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    final unread = snap.docs.where((d) => d.data()['read'] == false);
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final d in unread) {
      batch.update(d.reference, {'read': true});
      batch
          .update(_db.collection('fraud_alerts').doc(d.id), {'status': 'read'});
    }
    await batch.commit();
  }

  // ---------------- Financial insights ----------------

  Stream<List<FinancialInsightModel>> watchInsights(String userId) {
    return _db
        .collection('financial_insights')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => FinancialInsightModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> setInsightStatus(String id, String status) =>
      _db.collection('financial_insights').doc(id).update({'status': status});

  /// Marks every currently-unread insight for [userId] as read in one batch
  /// (Notifications screen's "mark all read") — same client-side-filter
  /// approach as [markAllNotificationsRead], for the same indexing reason.
  Future<void> markAllInsightsRead(String userId) async {
    final snap = await _db
        .collection('financial_insights')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    final unread = snap.docs.where((d) => d.data()['status'] == 'unread');
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final d in unread) {
      batch.update(d.reference, {'status': 'read'});
    }
    await batch.commit();
  }

  /// Regenerates this period's insights: new ones are created, ones that
  /// already exist for this (user, type, period) get their text refreshed
  /// in place (via `.update`, so `status`/`createdAt` — and therefore any
  /// prior read/dismiss — are preserved instead of resurrecting them).
  Future<void> upsertInsights(
      String userId, List<SmartInsight> insights, String period) async {
    if (insights.isEmpty) return;
    final col = _db.collection('financial_insights');
    final existing = await col
        .where('userId', isEqualTo: userId)
        .where('period', isEqualTo: period)
        .get();
    final existingIds = existing.docs.map((d) => d.id).toSet();

    final batch = _db.batch();
    final now = DateTime.now();
    for (final insight in insights) {
      final id = '${userId}_${insight.type}_$period';
      final ref = col.doc(id);
      if (existingIds.contains(id)) {
        batch.update(ref, {
          'title': insight.title,
          'message': insight.message,
          'sentiment': insight.sentiment,
        });
      } else {
        batch.set(
            ref,
            FinancialInsightModel(
              id: id,
              userId: userId,
              type: insight.type,
              title: insight.title,
              message: insight.message,
              sentiment: insight.sentiment,
              period: period,
              createdAt: now,
            ).toMap());
      }
    }
    await batch.commit();
  }
}
