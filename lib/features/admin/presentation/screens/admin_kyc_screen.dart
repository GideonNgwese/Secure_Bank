import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/kyc_model.dart';
import '../../../email/data/email_providers.dart';
import '../../data/admin_providers.dart';

/// KYC Management — approve / reject / request resubmission, with an
/// optional review note recorded alongside the decision. Migrated from the
/// legacy `lib/screens/admin/admin_kyc_screen.dart` into the new Admin
/// Module, extended with resubmission + review notes.
class AdminKycScreen extends ConsumerWidget {
  final String adminId;
  const AdminKycScreen({super.key, required this.adminId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kycAsync = ref.watch(adminKycProvider);
    return kycAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Text('No KYC submissions yet.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _KycCard(kyc: items[i], adminId: adminId),
              ),
        );
      },
    );
  }
}

class _KycCard extends ConsumerStatefulWidget {
  final KycModel kyc;
  final String adminId;
  const _KycCard({required this.kyc, required this.adminId});

  @override
  ConsumerState<_KycCard> createState() => _KycCardState();
}

class _KycCardState extends ConsumerState<_KycCard> {
  bool _busy = false;

  Future<void> _review(String status) async {
    final notesController = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(switch (status) {
          'approved' => 'Approve this submission?',
          'rejected' => 'Reject this submission?',
          _ => 'Request resubmission?',
        }),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Review notes (optional)',
              hintText: 'Visible in the audit log'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, notesController.text.trim()),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (notes == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).reviewKyc(
            docId: widget.kyc.id,
            userId: widget.kyc.userId,
            status: status,
            reviewedBy: widget.adminId,
            reviewNotes: notes,
          );
      if (status == 'approved' || status == 'rejected' || status == 'resubmission_requested') {
        final customer = ref
            .read(adminAuthUsersProvider)
            .valueOrNull
            ?.where((u) => u.uid == widget.kyc.userId)
            .firstOrNull;
        if (customer != null && customer.email.isNotEmpty) {
          ref.read(emailRepositoryProvider).kycStatus(
                userId: widget.kyc.userId,
                email: customer.email,
                name: customer.fullName,
                approved: status == 'approved',
                notes: notes.isEmpty ? null : notes,
              );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('KYC $status')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kyc = widget.kyc;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color statusColor = switch (kyc.status) {
      'approved' => AppTokens.success,
      'rejected' => AppTokens.danger,
      _ => AppTokens.warning,
    };
    final isPending = kyc.status == 'pending';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: isPending
            ? Border.all(color: AppTokens.warning.withValues(alpha: 0.5))
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(kyc.userName.isEmpty ? kyc.userId : kyc.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(kyc.status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${kyc.documentType} • ${kyc.documentReference}',
              style: const TextStyle(fontSize: 13)),
          Text('Submitted ${DateFormat.yMMMd().add_jm().format(kyc.createdAt)}',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          if (kyc.reviewNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Notes: ${kyc.reviewNotes}',
                style: TextStyle(
                    fontSize: 11.5, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
          ],
          if (kyc.documentUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(kyc.documentUrl,
                  height: 150, width: double.infinity, fit: BoxFit.cover),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _review('rejected'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTokens.danger),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _review('resubmission_requested'),
                    child: const Text('Resubmit', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _review('approved'),
                    style: FilledButton.styleFrom(backgroundColor: AppTokens.success),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
