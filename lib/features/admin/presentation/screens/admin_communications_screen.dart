import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/domain/auth_user.dart';
import '../../../../models/admin_notification_model.dart';
import '../../../../models/notification_thread_model.dart';
import '../../../email/data/email_providers.dart';
import '../../../support/data/support_providers.dart';
import '../../data/admin_providers.dart';
import 'admin_thread_detail_screen.dart';

/// The categories a targeted "send to some/all customers" message can use —
/// the announcement-only categories (maintenance/update/security/emergency)
/// live on the Announcements tab instead, always targeting everyone.
const _kNotificationCategories = [
  AdminNotificationCategory.generalAnnouncement,
  AdminNotificationCategory.securityAlert,
  AdminNotificationCategory.fraudWarning,
  AdminNotificationCategory.accountNotice,
];

const _kAnnouncementCategories = [
  AdminNotificationCategory.maintenanceNotice,
  AdminNotificationCategory.appUpdate,
  AdminNotificationCategory.securityAlert,
  AdminNotificationCategory.emergencyAlert,
];

/// Customer Support / System Announcements — one screen, three tabs, sharing
/// the same underlying broadcast mechanism (`AdminRepository.sendNotification`
/// fanning out into the customer's existing Notifications inbox). See
/// AdminNotificationModel's doc for why these aren't two separate systems.
class AdminCommunicationsScreen extends StatefulWidget {
  final String adminId;
  const AdminCommunicationsScreen({super.key, required this.adminId});

  @override
  State<AdminCommunicationsScreen> createState() =>
      _AdminCommunicationsScreenState();
}

class _AdminCommunicationsScreenState extends State<AdminCommunicationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: AppTokens.brand,
          tabs: const [
            Tab(text: 'Notification Center'),
            Tab(text: 'Announcements'),
            Tab(text: 'Response Center'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _ComposeTab(
                  adminId: widget.adminId,
                  categories: _kNotificationCategories,
                  allowTargeting: true),
              _ComposeTab(
                  adminId: widget.adminId,
                  categories: _kAnnouncementCategories,
                  allowTargeting: false),
              _ResponseCenterTab(adminId: widget.adminId),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComposeTab extends ConsumerStatefulWidget {
  final String adminId;
  final List<AdminNotificationCategory> categories;
  final bool allowTargeting;
  const _ComposeTab(
      {required this.adminId,
      required this.categories,
      required this.allowTargeting});

  @override
  ConsumerState<_ComposeTab> createState() => _ComposeTabState();
}

class _ComposeTabState extends ConsumerState<_ComposeTab> {
  late AdminNotificationCategory _category = widget.categories.first;
  String _priority = 'normal';
  AdminNotificationTarget _target = AdminNotificationTarget.all;
  final _title = TextEditingController();
  final _body = TextEditingController();
  final Set<String> _selectedUserIds = {};
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminAuthUsersProvider).valueOrNull ?? [];
    final customers = users.where((u) => !u.isAdmin).toList();
    final allSent = ref.watch(adminNotificationsProvider).valueOrNull ?? [];
    final categoryKeys = widget.categories.map((c) => c.key).toSet();
    final sentHere =
        allSent.where((n) => categoryKeys.contains(n.category.key)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Compose',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<AdminNotificationCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final c in widget.categories)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: (v) => setState(() => _priority = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              if (widget.allowTargeting) ...[
                const SizedBox(height: 12),
                SegmentedButton<AdminNotificationTarget>(
                  segments: const [
                    ButtonSegment(
                        value: AdminNotificationTarget.single,
                        label: Text('Single')),
                    ButtonSegment(
                        value: AdminNotificationTarget.multiple,
                        label: Text('Multiple')),
                    ButtonSegment(
                        value: AdminNotificationTarget.all,
                        label: Text('All')),
                  ],
                  selected: {_target},
                  onSelectionChanged: (s) =>
                      setState(() => _target = s.first),
                ),
                if (_target != AdminNotificationTarget.all) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _pickCustomers(customers),
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: Text(_selectedUserIds.isEmpty
                        ? 'Select customer(s)'
                        : '${_selectedUserIds.length} selected'),
                  ),
                ],
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Announcements are always sent to all customers.',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _sending ? null : () => _send(customers),
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_outlined),
                label: Text(_sending ? 'Sending…' : 'Send'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Sent (${sentHere.length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        if (sentHere.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
                child: Text('Nothing sent yet.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant))),
          )
        else
          for (final n in sentHere)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SentRow(notification: n),
            ),
      ],
    );
  }

  Future<void> _pickCustomers(List<AuthUser> customers) async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        final selected = Set<String>.from(_selectedUserIds);
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return AlertDialog(
            title: const Text('Select customers'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: customers.length,
                itemBuilder: (context, i) {
                  final u = customers[i];
                  return CheckboxListTile(
                    value: selected.contains(u.uid),
                    title: Text(u.fullName),
                    subtitle: Text(u.email),
                    onChanged: (v) => setSheetState(() {
                      if (v == true) {
                        selected.add(u.uid);
                      } else {
                        selected.remove(u.uid);
                      }
                    }),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  child: const Text('Done')),
            ],
          );
        });
      },
    );
    if (result != null) {
      setState(() => _selectedUserIds
        ..clear()
        ..addAll(result));
    }
  }

  Future<void> _send(List<AuthUser> customers) async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Title and message are required.')));
      return;
    }
    final target = widget.allowTargeting ? _target : AdminNotificationTarget.all;
    if (target != AdminNotificationTarget.all && _selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one customer.')));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(adminRepositoryProvider).sendNotification(
            category: _category,
            title: _title.text.trim(),
            body: _body.text.trim(),
            priority: _priority,
            targetType: target,
            targetUserIds: _selectedUserIds.toList(),
            allUserIds: customers.map((u) => u.uid).toList(),
            adminId: widget.adminId,
          );
      _sendAnnouncementEmails(customers, target);
      if (mounted) {
        _title.clear();
        _body.clear();
        setState(() => _selectedUserIds.clear());
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sent.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Fans the same broadcast out as email — mirrors the in-app notification
  /// fan-out `AdminRepository.sendNotification` already does. Not awaited
  /// per-recipient (a large "All customers" send shouldn't block the
  /// composer) — each call is itself best-effort via [EmailRepository].
  void _sendAnnouncementEmails(
      List<AuthUser> customers, AdminNotificationTarget target) {
    final recipients = target == AdminNotificationTarget.all
        ? customers
        : customers.where((u) => _selectedUserIds.contains(u.uid));
    final repo = ref.read(emailRepositoryProvider);
    final title = _title.text.trim();
    final body = _body.text.trim();
    for (final u in recipients) {
      if (u.email.isEmpty) continue;
      repo.adminAnnouncement(
        userId: u.uid,
        email: u.email,
        name: u.fullName,
        title: title,
        body: body,
        priority: _priority,
      );
    }
  }
}

class _SentRow extends StatelessWidget {
  final AdminNotificationModel notification;
  const _SentRow({required this.notification});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(notification.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Text(DateFormat.MMMd().add_jm().format(notification.createdAt),
                  style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Text(notification.body,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              _tag(notification.category.label, AppTokens.brand),
              _tag('${notification.recipientCount} recipient(s)',
                  scheme.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(fontSize: 9.5, color: color)),
      );
}

enum _ThreadFilter { all, unread, resolved, pending, security, fraud, general }

/// The real Customer Support Center: every conversation thread, searchable
/// and filterable, pinned ones first. Replaces the old flat "one response,
/// no reply-back" list.
class _ResponseCenterTab extends ConsumerStatefulWidget {
  final String adminId;
  const _ResponseCenterTab({required this.adminId});

  @override
  ConsumerState<_ResponseCenterTab> createState() => _ResponseCenterTabState();
}

class _ResponseCenterTabState extends ConsumerState<_ResponseCenterTab> {
  final _search = TextEditingController();
  _ThreadFilter _filter = _ThreadFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final threadsAsync = ref.watch(allThreadsProvider);
    return threadsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (all) {
        final q = _search.text.trim().toLowerCase();
        final filtered = all.where((t) {
          if (q.isNotEmpty &&
              !t.userName.toLowerCase().contains(q) &&
              !t.title.toLowerCase().contains(q) &&
              !t.lastMessagePreview.toLowerCase().contains(q)) {
            return false;
          }
          return switch (_filter) {
            _ThreadFilter.all => true,
            _ThreadFilter.unread => t.adminUnread,
            _ThreadFilter.resolved => t.status == ThreadStatus.resolved,
            _ThreadFilter.pending => t.status == ThreadStatus.pending,
            _ThreadFilter.security => t.category == ThreadCategory.security,
            _ThreadFilter.fraud => t.category == ThreadCategory.fraud,
            _ThreadFilter.general => t.category == ThreadCategory.general,
          };
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search conversations',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTokens.radius),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in _ThreadFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(switch (f) {
                                _ThreadFilter.all => 'All',
                                _ThreadFilter.unread => 'Unread',
                                _ThreadFilter.resolved => 'Resolved',
                                _ThreadFilter.pending => 'Pending',
                                _ThreadFilter.security => 'Security',
                                _ThreadFilter.fraud => 'Fraud',
                                _ThreadFilter.general => 'General',
                              }),
                              selected: _filter == f,
                              onSelected: (_) => setState(() => _filter = f),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                          all.isEmpty
                              ? 'No customer conversations yet.'
                              : 'No conversations match this search/filter.',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ThreadRow(thread: filtered[i], adminId: widget.adminId),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ThreadRow extends StatelessWidget {
  final NotificationThreadModel thread;
  final String adminId;
  const _ThreadRow({required this.thread, required this.adminId});

  Color get _statusColor => switch (thread.status) {
        ThreadStatus.resolved => AppTokens.success,
        ThreadStatus.closed => Colors.grey,
        ThreadStatus.pending => AppTokens.warning,
        ThreadStatus.open => AppTokens.brand,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: null,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminThreadDetailScreen(
                threadId: thread.id, adminId: adminId))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTokens.brand.withValues(alpha: 0.1),
              child: Text(
                  thread.userName.isNotEmpty ? thread.userName[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppTokens.brand)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (thread.pinned) ...[
                        const Icon(Icons.push_pin, size: 12, color: AppTokens.warning),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                            thread.userName.isEmpty ? 'Unknown customer' : thread.userName,
                            style: TextStyle(
                                fontWeight: thread.adminUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 13)),
                      ),
                      if (thread.adminUnread)
                        Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: AppTokens.brand, shape: BoxShape.circle)),
                    ],
                  ),
                  Text(thread.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 3),
                  Text(thread.lastMessagePreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      _badge(thread.status.label, _statusColor),
                      _badge(thread.category.label, AppTokens.brand),
                      _badge('${thread.messageCount}/$kMaxThreadMessages',
                          scheme.onSurfaceVariant),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
      );
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
