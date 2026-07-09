import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/header_provider.dart';
import '../../../../core/responsive/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/premium_header.dart';
import '../../../../models/fraud_alert_model.dart';
import '../../../fraud_detection/presentation/widgets/budget_alert_tile.dart';
import '../../../fraud_detection/presentation/widgets/fraud_empty_state.dart';
import '../../../fraud_detection/presentation/widgets/insight_card.dart';
import '../../../fraud_detection/presentation/screens/fraud_review_screen.dart';
import '../../../fraud_detection/presentation/widgets/risk_alert_card.dart';
import '../../../transactions/presentation/screens/transaction_detail_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../data/notifications_providers.dart';
import '../../domain/notification_item.dart';
import '../controllers/notifications_controller.dart';
import '../widgets/admin_message_card.dart';

/// The app-wide notification inbox — a unified, actionable feed over fraud
/// alerts, smart insights, and budget alerts (the same three sources the
/// Fraud Center's analytical timeline reads, just without the charts/health
/// score, and with dismissed items dropped rather than dimmed). This is
/// where every screen's header bell now points.
class NotificationsScreen extends ConsumerStatefulWidget {
  final String userId;
  const NotificationsScreen({super.key, required this.userId});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openTransaction(String transactionId) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
            userId: widget.userId, transactionId: transactionId)));
  }

  void _openReview(String transactionId) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FraudReviewScreen(
            userId: widget.userId, transactionId: transactionId)));
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(notificationFeedProvider(widget.userId));
    final unreadCount = ref.watch(headerUnreadCountProvider(widget.userId));
    final controller = ref.read(notificationsControllerProvider.notifier);

    return Scaffold(
      body: Column(
        children: [
          PremiumHeader(
            userId: widget.userId,
            title: 'Notifications',
            scrollController: _scrollController,
            showSecurityIndicator: false,
            onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(userId: widget.userId))),
            extraActions: [
              HeaderIconButton(
                icon: Icons.done_all_rounded,
                isDark: Theme.of(context).brightness == Brightness.dark,
                onTap: unreadCount > 0
                    ? () => controller.markAllRead(widget.userId)
                    : null,
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(notificationFeedProvider(widget.userId)),
              child: feedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(height: 12),
                        const Text('Unable to load notifications.',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Check your connection and try again.',
                            style: TextStyle(fontSize: 13)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => ref.invalidate(
                              notificationFeedProvider(widget.userId)),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) => ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    ResponsiveCenter(
                      maxWidth: 720,
                      scrollable: false,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: items.isEmpty
                          ? const FraudEmptyState()
                          : Column(
                              children: [
                                for (var i = 0; i < items.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: FadeSlideIn(
                                      duration: Duration(
                                          milliseconds:
                                              280 + (i.clamp(0, 8) * 35)),
                                      offsetY: 10,
                                      child: Dismissible(
                                        key: ValueKey(
                                            '${items[i].kind}-${items[i].id}'),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding:
                                              const EdgeInsets.only(right: 20),
                                          decoration: BoxDecoration(
                                            color: AppTokens.danger
                                                .withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(
                                                AppTokens.radius),
                                          ),
                                          child: const Icon(Icons.close,
                                              color: Colors.white),
                                        ),
                                        onDismissed: (_) =>
                                            controller.dismiss(items[i]),
                                        child: _item(items[i], controller),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(NotificationItem item, NotificationsController controller) {
    switch (item.kind) {
      case NotificationKind.fraud:
        final n = item.notification!;
        // Admin-authored broadcasts (Notification Center / Announcements)
        // live in this same collection but have no risk data to show — a
        // dedicated card that opens the full Reply Composer sheet instead of
        // a fraud risk badge.
        if (n.adminNotificationId.isNotEmpty) {
          return AdminMessageCard(
            notification: n,
            onDismiss: () => controller.dismiss(item),
          );
        }
        // RiskAlertCard is shared with Fraud Center, which reads
        // FraudAlertModel directly — adapt the notification's mirrored
        // fields into the same shape rather than forking the widget.
        final a = FraudAlertModel(
          id: n.id,
          userId: n.userId,
          transactionId: n.transactionId,
          riskScore: n.riskScore,
          riskLevel: n.riskLevel,
          reason: n.body,
          recommendation: n.recommendation,
          status: n.read ? 'read' : 'unread',
          createdAt: n.createdAt,
        );
        return RiskAlertCard(
          alert: a,
          onTap: () {
            if (!n.read) controller.markRead(item);
            if (n.transactionId.isNotEmpty) _openTransaction(n.transactionId);
          },
          onMarkRead: !n.read ? () => controller.markRead(item) : null,
          onDismiss: () => controller.dismiss(item),
          onReviewNow: n.actionRequired && n.transactionId.isNotEmpty
              ? () => _openReview(n.transactionId)
              : null,
        );
      case NotificationKind.insight:
        final ins = item.insight!;
        return InsightCard(
          insight: ins,
          onMarkRead: ins.isUnread ? () => controller.markRead(item) : null,
          onDismiss: () => controller.dismiss(item),
        );
      case NotificationKind.budget:
        return BudgetAlertTile(
          alert: item.budgetAlert!,
          onMarkRead: item.isUnread ? () => controller.markRead(item) : null,
        );
    }
  }
}
