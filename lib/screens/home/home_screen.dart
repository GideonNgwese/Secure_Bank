import 'package:flutter/material.dart';
import '../../features/accounts/presentation/account_list_screen.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/budget/presentation/screens/budget_list_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/transactions/presentation/screens/transaction_list_screen.dart';
import '../../utils/constants.dart';
import '../more/more_screen.dart';

/// The signed-in customer's bottom-nav shell: Dashboard, Accounts, Activity,
/// Budget, More. [AuthGate] is what decides a signed-in user reaches this
/// (vs. the admin dashboard or a suspended-account notice) — this widget
/// only renders the tabs, it doesn't re-derive who the user is.
class CustomerShell extends StatefulWidget {
  final AuthUser profile;
  const CustomerShell({super.key, required this.profile});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        userId: widget.profile.uid,
        userName: widget.profile.fullName,
        onNavigateToTab: (i) => setState(() => _index = i),
      ),
      AccountListScreen(userId: widget.profile.uid),
      TransactionListScreen(userId: widget.profile.uid),
      BudgetListScreen(userId: widget.profile.uid),
      MoreScreen(userId: widget.profile.uid, userName: widget.profile.fullName),
    ];

    return Scaffold(
      body: SafeArea(child: screens[_index]),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -2)),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: AppColors.primary),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet,
                    color: AppColors.primary),
                label: 'Accounts'),
            NavigationDestination(
                icon: Icon(Icons.swap_horiz),
                selectedIcon: Icon(Icons.swap_horiz, color: AppColors.primary),
                label: 'Activity'),
            NavigationDestination(
                icon: Icon(Icons.pie_chart_outline),
                selectedIcon: Icon(Icons.pie_chart, color: AppColors.primary),
                label: 'Budget'),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
          ],
        ),
      ),
    );
  }
}
