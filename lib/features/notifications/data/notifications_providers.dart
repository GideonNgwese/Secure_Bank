import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../fraud_detection/data/fraud_detection_providers.dart';
import '../domain/notification_item.dart';

/// Merges the real `notifications` collection with `financial_insights` and
/// budget alerts into one sorted feed — reuses fraud_detection's already-
/// scoped providers so there's a single listener per source shared with the
/// header badge and the Fraud Center screen.
final notificationFeedProvider =
    Provider.family<AsyncValue<List<NotificationItem>>, String>((ref, userId) {
  final notificationsAsync = ref.watch(notificationsProvider(userId));
  final insightsAsync = ref.watch(financialInsightsProvider(userId));
  final budgetAsync = ref.watch(legacyBudgetAlertsProvider(userId));

  if (notificationsAsync.isLoading ||
      insightsAsync.isLoading ||
      budgetAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (notificationsAsync.hasError) {
    return AsyncValue.error(
        notificationsAsync.error!, notificationsAsync.stackTrace!);
  }
  if (insightsAsync.hasError) {
    return AsyncValue.error(insightsAsync.error!, insightsAsync.stackTrace!);
  }
  if (budgetAsync.hasError) {
    return AsyncValue.error(budgetAsync.error!, budgetAsync.stackTrace!);
  }

  return AsyncValue.data(NotificationItem.build(
    notifications: notificationsAsync.value!,
    insights: insightsAsync.value!,
    budgetAlerts: budgetAsync.value!,
  ));
});
