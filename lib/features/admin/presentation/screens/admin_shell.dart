import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/domain/auth_user.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../support/data/support_providers.dart';
import '../../data/admin_providers.dart';
import 'admin_communications_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_fraud_monitoring_screen.dart';
import 'admin_more_screen.dart';
import 'admin_users_screen.dart';

/// The Admin Portal's top-level shell — an enterprise console layout
/// (NavigationRail on wide/desktop screens, bottom nav on mobile) replacing
/// the old `lib/screens/admin/admin_dashboard_screen.dart`'s fixed
/// BottomNavigationBar-only shell. Five destinations keep the nav usable at
/// every width: Dashboard, Users, Fraud, Communications, and a "More" menu
/// for the less-frequent KYC/Audit Log/Analytics areas.
class AdminShell extends ConsumerStatefulWidget {
  final AuthUser admin;
  const AdminShell({super.key, required this.admin});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _index = 0;

  static const _titles = [
    'Dashboard',
    'Customer Management',
    'Fraud Monitoring',
    'Communications',
    'More',
  ];

  @override
  Widget build(BuildContext context) {
    final adminId = widget.admin.uid;
    final pendingReviews = ref.watch(pendingFraudReviewCountProvider);
    final pendingKyc = ref.watch(pendingKycCountProvider);
    final unreadThreads = ref.watch(unreadThreadCountProvider);

    final screens = [
      AdminDashboardScreen(admin: widget.admin),
      AdminUsersScreen(adminId: adminId),
      AdminFraudMonitoringScreen(adminId: adminId),
      AdminCommunicationsScreen(adminId: adminId),
      AdminMoreScreen(adminId: adminId),
    ];

    final destinations = [
      const _NavDest(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard'),
      const _NavDest(icon: Icons.people_outline, selectedIcon: Icons.people, label: 'Users'),
      _NavDest(
          icon: Icons.gpp_maybe_outlined,
          selectedIcon: Icons.gpp_maybe,
          label: 'Fraud',
          badge: pendingReviews > 0 ? '$pendingReviews' : null),
      _NavDest(
          icon: Icons.campaign_outlined,
          selectedIcon: Icons.campaign,
          label: 'Comms',
          badge: unreadThreads > 0 ? '$unreadThreads' : null),
      _NavDest(
          icon: Icons.more_horiz,
          selectedIcon: Icons.more_horiz,
          label: 'More',
          badge: pendingKyc > 0 ? '$pendingKyc' : null),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 700;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Text(_titles[_index]),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: AppTokens.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('ADMIN',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold, color: AppTokens.brand)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NotificationsScreen(userId: adminId))),
          ),
        ],
      ),
      body: Row(
        children: [
          if (useRail)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              extended: width >= 1100,
              labelType: width >= 1100
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.selected,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: d.badge != null
                        ? Badge(label: Text(d.badge!), child: Icon(d.icon))
                        : Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          if (useRail) const VerticalDivider(width: 1),
          Expanded(child: screens[_index]),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: d.badge != null
                        ? Badge(label: Text(d.badge!), child: Icon(d.icon))
                        : Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
    );
  }
}

class _NavDest {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? badge;
  const _NavDest(
      {required this.icon, required this.selectedIcon, required this.label, this.badge});
}
