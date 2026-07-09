import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/notification_thread_model.dart';
import '../../../../models/thread_message_model.dart';
import '../../../support/data/support_providers.dart';

/// Full conversation view for one thread — customer identity, the
/// originating notification, the message history, and the admin's reply
/// composer + status actions (Resolve / Request More Info / Close / Pin /
/// Forward). Pushed from the Response Center list.
class AdminThreadDetailScreen extends ConsumerStatefulWidget {
  final String threadId;
  final String adminId;
  const AdminThreadDetailScreen(
      {super.key, required this.threadId, required this.adminId});

  @override
  ConsumerState<AdminThreadDetailScreen> createState() =>
      _AdminThreadDetailScreenState();
}

class _AdminThreadDetailScreenState
    extends ConsumerState<AdminThreadDetailScreen> {
  final _textController = TextEditingController();
  bool _sending = false;
  bool _markedRead = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send(NotificationThreadModel thread) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportRepositoryProvider).sendMessage(
            notificationId: thread.notificationId,
            userId: thread.userId,
            userName: thread.userName,
            userEmail: thread.userEmail,
            title: thread.title,
            category: thread.category,
            priority: thread.priority,
            senderId: widget.adminId,
            senderRole: 'admin',
            receiverId: thread.userId,
            message: text,
          );
      _textController.clear();
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

  Future<void> _setStatus(NotificationThreadModel thread, ThreadStatus status) {
    return ref.read(supportRepositoryProvider).updateStatus(
          threadId: thread.id,
          status: status,
          adminId: widget.adminId,
          targetUserId: thread.userId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final threadAsync = ref.watch(threadProvider(widget.threadId));
    final messagesAsync = ref.watch(threadMessagesProvider(widget.threadId));
    final thread = threadAsync.valueOrNull;
    final messages = messagesAsync.valueOrNull ?? const <ThreadMessageModel>[];

    if (thread != null && thread.adminUnread && !_markedRead) {
      _markedRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(supportRepositoryProvider)
            .markRead(threadId: widget.threadId, readerRole: 'admin');
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: thread == null
            ? const Text('Conversation')
            : Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTokens.brand.withValues(alpha: 0.1),
                    child: Text(
                        thread.userName.isNotEmpty
                            ? thread.userName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: AppTokens.brand, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            thread.userName.isEmpty
                                ? 'Unknown customer'
                                : thread.userName,
                            style: const TextStyle(fontSize: 14)),
                        if (thread.userEmail.isNotEmpty)
                          Text(thread.userEmail,
                              style: const TextStyle(
                                  fontSize: 10.5, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
        actions: thread == null
            ? null
            : [
                IconButton(
                  tooltip: thread.pinned ? 'Unpin' : 'Pin',
                  icon: Icon(thread.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                  onPressed: () => ref
                      .read(supportRepositoryProvider)
                      .setPinned(threadId: thread.id, pinned: !thread.pinned),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'resolve':
                        _setStatus(thread, ThreadStatus.resolved);
                      case 'pending':
                        _setStatus(thread, ThreadStatus.pending);
                      case 'close':
                        _setStatus(thread, ThreadStatus.closed);
                      case 'forward':
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Internal forwarding is coming soon.')));
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'resolve', child: Text('Mark Resolved')),
                    PopupMenuItem(
                        value: 'pending', child: Text('Request More Information')),
                    PopupMenuItem(value: 'close', child: Text('Close Conversation')),
                    PopupMenuItem(
                        value: 'forward', child: Text('Forward Internally')),
                  ],
                ),
              ],
      ),
      body: thread == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _OriginalNotificationCard(thread: thread),
                      const SizedBox(height: 16),
                      for (final m in messages)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AdminMessageBubble(message: m),
                        ),
                    ],
                  ),
                ),
                if (thread.atMessageLimit)
                  _Banner(
                      text:
                          'This conversation has reached its $kMaxThreadMessages-reply limit.')
                else if (thread.status == ThreadStatus.closed)
                  const _Banner(text: 'This conversation is closed.')
                else
                  _ReplyBar(
                    controller: _textController,
                    sending: _sending,
                    onSend: () => _send(thread),
                  ),
              ],
            ),
    );
  }
}

class _OriginalNotificationCard extends StatelessWidget {
  final NotificationThreadModel thread;
  const _OriginalNotificationCard({required this.thread});

  Color get _color => switch (thread.status) {
        ThreadStatus.resolved => AppTokens.success,
        ThreadStatus.closed => Colors.grey,
        ThreadStatus.pending => AppTokens.warning,
        ThreadStatus.open => AppTokens.brand,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(thread.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _tag(thread.status.label, _color),
              _tag(thread.category.label, AppTokens.brand),
              _tag(
                  '${thread.priority[0].toUpperCase()}${thread.priority.substring(1)} priority',
                  AppTokens.warning),
              _tag('${thread.messageCount}/$kMaxThreadMessages replies',
                  scheme.onSurfaceVariant),
              _tag(
                  'Started ${DateFormat.yMMMd().format(thread.createdAt)}',
                  scheme.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      );
}

class _AdminMessageBubble extends StatelessWidget {
  final ThreadMessageModel message;
  const _AdminMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.isFromAdmin;
    final scheme = Theme.of(context).colorScheme;
    final bg = mine ? AppTokens.brand : scheme.surfaceContainerHighest;
    final fg = mine ? Colors.white : scheme.onSurface;
    final text = message.message.isNotEmpty
        ? message.message
        : (message.responseType ?? '');
    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                Text(text, style: TextStyle(color: fg, fontSize: 13)),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(DateFormat.MMMd().add_jm().format(message.createdAt),
                        style: TextStyle(
                            color: fg.withValues(alpha: 0.7), fontSize: 9.5)),
                    if (mine && message.read) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.done_all, size: 11, color: fg.withValues(alpha: 0.85)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _ReplyBar(
      {required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(
          14, 10, 14, 10 + MediaQuery.of(context).viewInsets.bottom.clamp(0, 200)),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Reply to customer…',
                isDense: true,
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  const _Banner({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: scheme.surfaceContainerHighest,
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
    );
  }
}
