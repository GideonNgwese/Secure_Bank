import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import 'admin_analytics_screen.dart';
import 'admin_audit_log_screen.dart';
import 'admin_kyc_screen.dart';

/// Secondary Admin Module areas, reached less often than the primary 4 tabs
/// — kept off the main nav to avoid overcrowding a 5-item bottom bar/rail.
class AdminMoreScreen extends ConsumerWidget {
  final String adminId;
  const AdminMoreScreen({super.key, required this.adminId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Tile(
          icon: Icons.badge_outlined,
          title: 'KYC Review',
          subtitle: 'Approve, reject, or request resubmission',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('KYC Review')),
                  body: AdminKycScreen(adminId: adminId)))),
        ),
        _Tile(
          icon: Icons.history,
          title: 'Audit Log',
          subtitle: 'Every recorded admin and customer action',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Audit Log')),
                  body: const AdminAuditLogScreen()))),
        ),
        _Tile(
          icon: Icons.analytics_outlined,
          title: 'Analytics',
          subtitle: 'KYC, notification, and fraud statistics',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Analytics')),
                  body: const AdminAnalyticsScreen()))),
        ),
        const Divider(height: 32),
        _Tile(
          icon: Icons.logout,
          title: 'Sign out',
          subtitle: null,
          color: AppTokens.danger,
          onTap: () async {
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) {
              Navigator.of(context).popUntil((r) => r.isFirst);
            }
          },
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = color ?? AppTokens.brand;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration:
              BoxDecoration(color: tint.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: tint, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: tint)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
