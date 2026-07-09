import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/domain/auth_user.dart';
import '../../../email/data/email_providers.dart';
import '../../../fraud_detection/domain/risk_level.dart';
import '../../data/admin_providers.dart';

enum _StatusFilter { all, active, suspended }

enum _VerificationFilter { all, notSubmitted, pending, approved, rejected }

/// Customer Management — search/filter/suspend/reactivate + a read-only
/// profile summary. Deliberately shows NOTHING beyond identity/status
/// fields: no account numbers, balances, transaction data, or credentials
/// (those live in separate collections this screen never reads).
class AdminUsersScreen extends ConsumerStatefulWidget {
  final String adminId;
  const AdminUsersScreen({super.key, required this.adminId});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _search = TextEditingController();
  _StatusFilter _statusFilter = _StatusFilter.all;
  _VerificationFilter _verificationFilter = _VerificationFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminAuthUsersProvider);
    final riskLevels = ref.watch(adminUserRiskLevelsProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (all) {
        final customers = all.where((u) => !u.isAdmin).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final q = _search.text.trim().toLowerCase();
        final filtered = customers.where((u) {
          if (q.isNotEmpty &&
              !u.fullName.toLowerCase().contains(q) &&
              !u.email.toLowerCase().contains(q) &&
              !u.phone.toLowerCase().contains(q)) {
            return false;
          }
          if (_statusFilter == _StatusFilter.active && u.isSuspended) {
            return false;
          }
          if (_statusFilter == _StatusFilter.suspended && !u.isSuspended) {
            return false;
          }
          final wantKyc = switch (_verificationFilter) {
            _VerificationFilter.all => null,
            _VerificationFilter.notSubmitted => 'not_submitted',
            _VerificationFilter.pending => 'pending',
            _VerificationFilter.approved => 'approved',
            _VerificationFilter.rejected => 'rejected',
          };
          if (wantKyc != null && u.kycStatus != wantKyc) return false;
          return true;
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
                      hintText: 'Search by name, email, or phone',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTokens.radius),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in _StatusFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(switch (f) {
                                _StatusFilter.all => 'All',
                                _StatusFilter.active => 'Active',
                                _StatusFilter.suspended => 'Suspended',
                              }),
                              selected: _statusFilter == f,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = f),
                            ),
                          ),
                        const SizedBox(width: 8),
                        for (final f in _VerificationFilter.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(switch (f) {
                                _VerificationFilter.all => 'Any KYC',
                                _VerificationFilter.notSubmitted =>
                                  'Not submitted',
                                _VerificationFilter.pending => 'KYC pending',
                                _VerificationFilter.approved =>
                                  'KYC approved',
                                _VerificationFilter.rejected => 'KYC rejected',
                              }),
                              selected: _verificationFilter == f,
                              onSelected: (_) =>
                                  setState(() => _verificationFilter = f),
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
                          customers.isEmpty
                              ? 'No customers registered yet.'
                              : 'No customers match this search/filter.',
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _UserRow(
                        user: filtered[i],
                        riskLevel: riskLevels[filtered[i].uid] ?? 'Low',
                        adminId: widget.adminId,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _UserRow extends ConsumerWidget {
  final AuthUser user;
  final String riskLevel;
  final String adminId;
  const _UserRow(
      {required this.user, required this.riskLevel, required this.adminId});

  Color _kycColor(String status) => switch (status) {
        'approved' => AppTokens.success,
        'rejected' => AppTokens.danger,
        'pending' => AppTokens.warning,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final level = RiskLevelX.fromName(riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        onTap: () => _openProfileSummary(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTokens.brand.withValues(alpha: 0.1),
                child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: AppTokens.brand)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName.isEmpty ? 'Unnamed customer' : user.fullName,
                        style:
                            const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    Text(user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _badge(user.isSuspended ? 'Suspended' : 'Active',
                            user.isSuspended ? AppTokens.danger : AppTokens.success),
                        _badge('KYC: ${user.kycStatus}',
                            _kycColor(user.kycStatus)),
                        _badge('${level.label} risk', level.color),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => _handleAction(context, ref, v),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'summary', child: Text('View profile summary')),
                  PopupMenuItem(
                    value: user.isSuspended ? 'reactivate' : 'suspend',
                    child: Text(
                        user.isSuspended ? 'Reactivate account' : 'Suspend account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'summary':
        _openProfileSummary(context, ref);
      case 'suspend':
        _confirmStatusChange(context, ref, suspend: true);
      case 'reactivate':
        _confirmStatusChange(context, ref, suspend: false);
    }
  }

  Future<void> _confirmStatusChange(BuildContext context, WidgetRef ref,
      {required bool suspend}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(suspend ? 'Suspend this account?' : 'Reactivate this account?'),
        content: Text(suspend
            ? '${user.fullName} will be immediately signed out of any active session and blocked from logging back in.'
            : '${user.fullName} will regain full access to their account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: suspend ? AppTokens.danger : AppTokens.success),
            child: Text(suspend ? 'Suspend' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(adminRepositoryProvider).setUserActiveStatus(
          userId: user.uid,
          isActive: !suspend,
          adminId: adminId,
        );
    if (user.email.isNotEmpty) {
      ref.read(emailRepositoryProvider).accountStatusChanged(
            userId: user.uid,
            email: user.email,
            name: user.fullName,
            suspended: suspend,
          );
    }
  }

  void _openProfileSummary(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProfileSummarySheet(user: user, riskLevel: riskLevel),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9.5, color: color, fontWeight: FontWeight.w700)),
      );
}

/// Read-only profile summary — the full set of fields the Admin Module is
/// allowed to see (identity, registration, status, verification, risk).
/// No account numbers, balances, or transaction data anywhere in this sheet.
class _ProfileSummarySheet extends StatelessWidget {
  final AuthUser user;
  final String riskLevel;
  const _ProfileSummarySheet({required this.user, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final level = RiskLevelX.fromName(riskLevel);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTokens.brand.withValues(alpha: 0.1),
                  child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: AppTokens.brand, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(user.email,
                          style: TextStyle(
                              fontSize: 12.5, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _row(context, 'Phone', user.phone.isEmpty ? '—' : user.phone),
            _row(context, 'Registration date',
                DateFormat.yMMMd().format(user.createdAt)),
            _row(
                context,
                'Last login',
                user.lastLogin != null
                    ? DateFormat.yMMMd().add_jm().format(user.lastLogin!)
                    : 'Never'),
            _row(context, 'Account status',
                user.isSuspended ? 'Suspended' : 'Active'),
            _row(context, 'Verification status', user.kycStatus),
            _row(context, 'Region',
                user.region.isEmpty ? '—' : user.region, last: true),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                  color: level.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(level.icon, color: level.color, size: 16),
                  const SizedBox(width: 8),
                  Text('Fraud risk level: ${level.label}',
                      style: TextStyle(
                          color: level.color, fontWeight: FontWeight.w600, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
                'Account numbers, balances, and transaction details are never shown to platform administrators.',
                style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {bool last = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ),
    );
  }
}
