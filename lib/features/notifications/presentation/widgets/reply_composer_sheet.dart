import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/data/auth_providers.dart';
import '../../../../models/notification_model.dart';
import '../../../../models/notification_thread_model.dart';
import '../../../../models/support_response_model.dart';
import '../../../../models/thread_message_model.dart';
import '../../../support/data/support_providers.dart';

/// The premium reply composer — a glassmorphic bottom sheet replacing the
/// old inline quick-reaction row on [AdminMessageCard]. Shows the full
/// notification context, the conversation so far (if any), a live
/// sent/delivered/read/resolved status stepper for the customer's last
/// message, and the compose row (quick reactions + a 250-char text field).
class ReplyComposerSheet extends ConsumerStatefulWidget {
  final NotificationModel notification;
  const ReplyComposerSheet({super.key, required this.notification});

  static Future<void> show(BuildContext context, NotificationModel notification) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReplyComposerSheet(notification: notification),
    );
  }

  @override
  ConsumerState<ReplyComposerSheet> createState() => _ReplyComposerSheetState();
}

class _ReplyComposerSheetState extends ConsumerState<ReplyComposerSheet> {
  final _textController = TextEditingController();
  bool _sending = false;
  bool _justSent = false;
  bool _markedRead = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String get _threadId => widget.notification.id;

  Color _priorityColor(String priority) => switch (priority) {
        'critical' => AppTokens.danger,
        'high' => AppTokens.warning,
        _ => AppTokens.brand,
      };

  bool get _isSecurity {
    final t = widget.notification.type;
    return t == 'security_alert' ||
        t == 'emergency_alert' ||
        t == 'fraud_warning' ||
        widget.notification.riskLevel.isNotEmpty &&
            widget.notification.riskLevel != 'Low';
  }

  Future<void> _send(String? responseType, String message) async {
    final me = ref.read(firebaseAuthProvider).currentUser;
    if (me == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportRepositoryProvider).sendMessage(
            notificationId: widget.notification.id,
            userId: widget.notification.userId,
            userName: me.displayName ?? '',
            userEmail: me.email ?? '',
            title: widget.notification.title,
            category:
                ThreadCategoryX.fromNotificationType(widget.notification.type),
            priority: widget.notification.priority,
            senderId: me.uid,
            senderRole: 'customer',
            receiverId: 'admin',
            message: message,
            responseType: responseType,
          );
      _textController.clear();
      if (mounted) {
        setState(() => _justSent = true);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) setState(() => _justSent = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is StateError
                ? e.message
                : 'Could not send your reply. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadAsync = ref.watch(threadProvider(_threadId));
    final messagesAsync = ref.watch(threadMessagesProvider(_threadId));
    final thread = threadAsync.valueOrNull;
    final messages = messagesAsync.valueOrNull ?? const <ThreadMessageModel>[];

    // Mark admin messages read the moment this sheet is open and we know a
    // thread exists — matches the customer actually viewing the reply.
    if (thread != null && thread.customerUnread && !_markedRead) {
      _markedRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(supportRepositoryProvider)
            .markRead(threadId: _threadId, readerRole: 'customer');
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final atLimit = thread?.atMessageLimit ?? false;
    final closed = thread?.status == ThreadStatus.closed;
    final canReply = !atLimit && !closed;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppTokens.radiusLg)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? const Color(0xFF141634) : Colors.white)
                  .withValues(alpha: 0.88),
              border: Border(
                top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.04)),
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Conversation',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16)),
                              TextButton(
                                onPressed: () => Navigator.of(context).maybePop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _NotificationContextCard(
                            notification: widget.notification,
                            priorityColor:
                                _priorityColor(widget.notification.priority),
                            isSecurity: _isSecurity,
                          ),
                          if (messages.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            for (final m in messages)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _MessageBubble(message: m),
                              ),
                          ],
                          if (messages.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _StatusStepper(
                              lastCustomerMessage: messages.reversed
                                  .where((m) => m.isFromCustomer)
                                  .firstOrNull,
                              thread: thread,
                            ),
                          ],
                          if (atLimit) ...[
                            const SizedBox(height: 14),
                            _InfoBanner(
                              icon: Icons.info_outline,
                              text:
                                  'This conversation has reached its $kMaxThreadMessages-reply limit. '
                                  'Our team will follow up shortly.',
                            ),
                          ] else if (closed) ...[
                            const SizedBox(height: 14),
                            const _InfoBanner(
                              icon: Icons.check_circle_outline,
                              text: 'This conversation has been closed.',
                            ),
                          ],
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                    if (canReply)
                      _ComposeRow(
                        controller: _textController,
                        sending: _sending,
                        onQuickResponse: (type) => _send(type.key, ''),
                        onSend: (text) => _send(SupportResponseType.text.key, text),
                      ),
                  ],
                ),
                if (_justSent) const _SentConfetti(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationContextCard extends StatelessWidget {
  final NotificationModel notification;
  final Color priorityColor;
  final bool isSecurity;
  const _NotificationContextCard(
      {required this.notification,
      required this.priorityColor,
      required this.isSecurity});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: priorityColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle),
                child: Icon(Icons.campaign_outlined, color: priorityColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(notification.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(notification.body, style: const TextStyle(fontSize: 13, height: 1.35)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _badge('From: SecureBank Admin', scheme.onSurfaceVariant,
                  icon: Icons.verified_user_outlined),
              _badge(DateFormat.yMMMd().add_jm().format(notification.createdAt),
                  scheme.onSurfaceVariant,
                  icon: Icons.schedule_outlined),
              _badge('${notification.priority[0].toUpperCase()}${notification.priority.substring(1)} priority',
                  priorityColor),
              if (isSecurity)
                _badge('Security', AppTokens.danger, icon: Icons.shield_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  final ThreadMessageModel message;
  const _MessageBubble({required this.message});

  String get _displayText {
    if (!message.isFromCustomer || message.message.isNotEmpty) {
      return message.message;
    }
    final type = SupportResponseTypeX.fromKey(message.responseType ?? '');
    return '${type.emoji} ${type.label}';
  }

  @override
  Widget build(BuildContext context) {
    final mine = message.isFromCustomer;
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? AppTokens.brand : scheme.surfaceContainerHighest;
    final fg = mine ? Colors.white : scheme.onSurface;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 8), child: child),
      ),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(mine ? 14 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_displayText, style: TextStyle(color: fg, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(DateFormat.MMMd().add_jm().format(message.createdAt),
                      style: TextStyle(
                          color: fg.withValues(alpha: 0.7), fontSize: 9.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final ThreadMessageModel? lastCustomerMessage;
  final NotificationThreadModel? thread;
  const _StatusStepper({required this.lastCustomerMessage, required this.thread});

  @override
  Widget build(BuildContext context) {
    if (lastCustomerMessage == null) return const SizedBox.shrink();
    final resolved = thread?.status == ThreadStatus.resolved;
    final read = lastCustomerMessage!.read;
    final steps = [
      ('Sent', true),
      ('Delivered', true),
      ('Read by Admin', read || resolved),
      ('Resolved', resolved),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            _StepDot(label: steps[i].$1, done: steps[i].$2),
            if (i != steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: (steps[i].$2 && steps[i + 1].$2)
                      ? AppTokens.success
                      : Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.4),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool done;
  const _StepDot({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = done ? AppTokens.success : scheme.onSurfaceVariant;
    return Column(
      children: [
        Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16, color: color),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant))),
        ],
      ),
    );
  }
}

class _ComposeRow extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final ValueChanged<SupportResponseType> onQuickResponse;
  final ValueChanged<String> onSend;
  const _ComposeRow({
    required this.controller,
    required this.sending,
    required this.onQuickResponse,
    required this.onSend,
  });

  @override
  State<_ComposeRow> createState() => _ComposeRowState();
}

class _ComposeRowState extends State<_ComposeRow> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final len = widget.controller.text.length;
    final nearLimit = len > kSupportResponseMaxChars - 30;

    return Container(
      padding: EdgeInsets.fromLTRB(
          14, 10, 14, 10 + MediaQuery.of(context).viewInsets.bottom.clamp(0, 200)),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF141634) : Colors.white)
            .withValues(alpha: 0.96),
        border: Border(
            top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : scheme.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final type in [
                  SupportResponseType.acknowledge,
                  SupportResponseType.confirm,
                  SupportResponseType.thankYou,
                  SupportResponseType.needHelp,
                  SupportResponseType.contactSupport,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      avatar: Text(type.emoji),
                      label: Text(type.label, style: const TextStyle(fontSize: 11.5)),
                      onPressed: widget.sending
                          ? null
                          : () => widget.onQuickResponse(type),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  maxLines: 4,
                  minLines: 1,
                  maxLength: kSupportResponseMaxChars,
                  decoration: InputDecoration(
                    hintText: 'Write a short reply…',
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF3F5F9),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                        borderSide: BorderSide.none),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(
                enabled: !widget.sending &&
                    widget.controller.text.trim().isNotEmpty,
                sending: widget.sending,
                onPressed: () {
                  final text = widget.controller.text.trim();
                  if (text.isNotEmpty) widget.onSend(text);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text('$len/$kSupportResponseMaxChars',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: nearLimit ? AppTokens.warning : scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatefulWidget {
  final bool enabled;
  final bool sending;
  final VoidCallback onPressed;
  const _SendButton(
      {required this.enabled, required this.sending, required this.onPressed});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _scale = 0.88) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _scale = 1) : null,
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.enabled
                  ? [AppTokens.brand, AppTokens.brandDeep]
                  : [Colors.grey.shade400, Colors.grey.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                        color: AppTokens.brand.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ]
                : null,
          ),
          child: widget.sending
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

/// A brief celebratory burst after a successful send — cheap, tasteful, and
/// respects the "beautiful send animation" ask without a particle package.
class _SentConfetti extends StatelessWidget {
  const _SentConfetti();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.elasticOut,
          builder: (context, v, child) =>
              Transform.scale(scale: v.clamp(0, 1.15), child: child),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: AppTokens.success.withValues(alpha: 0.94),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppTokens.success.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4),
                ]),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
