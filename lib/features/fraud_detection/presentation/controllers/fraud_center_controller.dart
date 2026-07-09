import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/transaction_model.dart';
import '../../data/fraud_detection_providers.dart';
import '../../domain/smart_insights.dart';

/// Drives the Fraud Center screen's mutations: (re)generating this month's
/// insights on load, and mark-read/dismiss for both alerts and insights.
class FraudCenterController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Computes fresh insights from [allTx] and upserts them for the current
  /// month — safe to call every time the screen opens (existing insights
  /// are refreshed in place, not duplicated or reset to unread).
  Future<void> generateInsights(
      String userId, List<TransactionModel> allTx) async {
    final now = DateTime.now();
    final period = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final insights = SmartInsightsEngine.generate(allTx, now);
    await ref
        .read(fraudDetectionRepositoryProvider)
        .upsertInsights(userId, insights, period);
  }

  // id here is the fraud alert's doc id, which is always the same as its
  // paired `notifications` doc's id (both keyed by transactionId) — so
  // marking read/dismissed from the Fraud Center timeline stays in sync
  // with the Notification Center's badge/feed, and vice versa.
  Future<void> markAlertRead(String id) => ref
      .read(fraudDetectionRepositoryProvider)
      .setNotificationStatus(id, read: true, alertStatus: 'read');

  Future<void> dismissAlert(String id) => ref
      .read(fraudDetectionRepositoryProvider)
      .setNotificationStatus(id, dismissed: true, alertStatus: 'dismissed');

  Future<void> markInsightRead(String id) =>
      ref.read(fraudDetectionRepositoryProvider).setInsightStatus(id, 'read');

  Future<void> dismissInsight(String id) => ref
      .read(fraudDetectionRepositoryProvider)
      .setInsightStatus(id, 'dismissed');
}

final fraudCenterControllerProvider =
    AutoDisposeAsyncNotifierProvider<FraudCenterController, void>(
        FraudCenterController.new);
