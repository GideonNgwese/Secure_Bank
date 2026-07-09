import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/notification_model.dart';
import '../../../../models/notification_thread_model.dart';
import '../../../support/data/support_providers.dart';
import 'reply_composer_sheet.dart';

/// An admin-authored broadcast (Notification Center message or System
/// Announcement) in the customer's inbox — distinct from `RiskAlertCard`
/// (fraud alerts) since risk-level badges don't apply here. Tapping "Reply"
/// opens the full [ReplyComposerSheet]; this card itself just shows a
/// summary and the conversation's current status.
class AdminMessageCard extends ConsumerWidget {
  final NotificationModel notification;
  final VoidCallback? onDismiss;

  const AdminMessageCard({
    super.key,
    required this.notification,
    this.onDismiss,
  });

  Color get _priorityColor => switch (notification.priority) {
        'critical' => AppTokens.danger,
        'high' => AppTokens.warning,
        _ => AppTokens.brand,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thread =
        ref.watch(threadProvider(notification.id)).valueOrNull;

    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        onTap: () => ReplyComposerSheet.show(context, notification),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radius),
            border:
                Border.all(color: _priorityColor.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: _priorityColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle),
                    child: Icon(Icons.campaign_outlined,
                        color: _priorityColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(notification.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                  Text(DateFormat.MMMd().add_jm().format(notification.createdAt),
                      style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 10),
              Text(notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (thread != null) _ThreadStatusChip(thread: thread),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => ReplyComposerSheet.show(context, notification),
                    icon: Icon(
                        thread == null
                            ? Icons.reply_outlined
                            : Icons.forum_outlined,
                        size: 16),
                    label: Text(thread == null ? 'Reply' : 'View conversation',
                        style: const TextStyle(fontSize: 12)),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: scheme.onSurfaceVariant,
                      onPressed: onDismiss,
                      tooltip: 'Dismiss',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadStatusChip extends StatelessWidget {
  final NotificationThreadModel thread;
  const _ThreadStatusChip({required this.thread});

  Color get _color => switch (thread.status) {
        ThreadStatus.resolved => AppTokens.success,
        ThreadStatus.closed => Colors.grey,
        ThreadStatus.pending => AppTokens.warning,
        ThreadStatus.open => AppTokens.brand,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8)),
      child: Text(thread.status.label,
          style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w700)),
    );
  }
}
