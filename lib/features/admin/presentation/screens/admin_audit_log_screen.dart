import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/admin_providers.dart';

/// Audit Log — every recorded action (customer + admin) from the existing
/// `activity_logs` collection (reused as-is, per "reuse existing collections
/// wherever appropriate" — no separate `audit_logs` collection was
/// introduced). Shows the acting user, the target user (when the action was
/// performed ON someone else, e.g. suspend/KYC review), and timestamp.
class AdminAuditLogScreen extends ConsumerStatefulWidget {
  const AdminAuditLogScreen({super.key});

  @override
  ConsumerState<AdminAuditLogScreen> createState() => _AdminAuditLogScreenState();
}

class _AdminAuditLogScreenState extends ConsumerState<AdminAuditLogScreen> {
  String _search = '';

  IconData _iconFor(String action) {
    final a = action.toLowerCase();
    if (a.contains('suspend') || a.contains('reactivat')) return Icons.person;
    if (a.contains('kyc')) return Icons.badge_outlined;
    if (a.contains('fraud')) return Icons.shield_outlined;
    if (a.contains('sent') || a.contains('notification')) return Icons.campaign_outlined;
    if (a.contains('logged in')) return Icons.login;
    if (a.contains('registered')) return Icons.person_add;
    if (a.contains('account')) return Icons.account_balance_wallet_outlined;
    if (a.contains('import')) return Icons.upload_file;
    if (a.contains('added') || a.contains('edited')) return Icons.swap_horiz;
    return Icons.history;
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(adminActivityLogsProvider);
    final users = ref.watch(adminAuthUsersProvider).valueOrNull ?? [];
    final namesById = {for (final u in users) u.uid: u.fullName};

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (logs) {
        final q = _search.trim().toLowerCase();
        final filtered = q.isEmpty
            ? logs
            : logs
                .where((l) =>
                    (l['action'] ?? '').toString().toLowerCase().contains(q))
                .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search actions',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                      borderSide: BorderSide.none),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No activity logged yet.',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final log = filtered[i];
                        final action = (log['action'] ?? '').toString();
                        final uid = (log['userId'] ?? '').toString();
                        final targetUserId = (log['targetUserId'] ?? '').toString();
                        final created =
                            DateTime.tryParse((log['createdAt'] ?? '').toString());
                        final actorName = namesById[uid] ?? uid;
                        final targetName =
                            targetUserId.isEmpty ? null : (namesById[targetUserId] ?? targetUserId);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppTokens.brand.withValues(alpha: 0.1),
                            child: Icon(_iconFor(action), color: AppTokens.brand, size: 18),
                          ),
                          title: Text(action, style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            [
                              actorName,
                              if (targetName != null) '→ $targetName',
                              if (created != null)
                                DateFormat.yMMMd().add_jm().format(created),
                            ].join(' • '),
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
