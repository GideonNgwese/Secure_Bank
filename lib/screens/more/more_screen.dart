import 'package:flutter/material.dart';
import '../../core/widgets/premium_header.dart';
import '../../features/fraud_detection/presentation/screens/fraud_center_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';
import '../profile/profile_kyc_screen.dart';

/// Secondary customer screens grouped under a single "More" tab so the
/// bottom navigation stays uncluttered: Alerts, Reports, Profile & KYC.
class MoreScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const MoreScreen({super.key, required this.userId, required this.userName});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.userId;
    final userName = widget.userName;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          PremiumHeader(
            userId: userId,
            title: 'More',
            scrollController: _scrollController,
            onAvatarTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ProfileKycScreen(userId: userId))),
            onNotificationsTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => NotificationsScreen(userId: userId))),
            onSettingsTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettingsScreen(userId: userId))),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                _MenuTile(
                  icon: Icons.notifications_active_outlined,
                  color: AppColors.warning,
                  title: 'Notifications',
                  subtitle: 'Fraud alerts, budget alerts, and smart insights',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NotificationsScreen(userId: userId))),
                ),
                _MenuTile(
                  icon: Icons.shield_outlined,
                  color: AppColors.danger,
                  title: 'Fraud & Insights',
                  subtitle:
                      'Security score, risk analytics, and financial health',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FraudCenterScreen(userId: userId))),
                ),
                _MenuTile(
                  icon: Icons.assessment_outlined,
                  color: AppColors.primary,
                  title: 'Reports & Analytics',
                  subtitle:
                      'Financial insights, budgets, and exportable reports',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          ReportsScreen(userId: userId, userName: userName))),
                ),
                _MenuTile(
                  icon: Icons.person_outline,
                  color: AppColors.success,
                  title: 'Profile & KYC',
                  subtitle: 'Your details and identity verification status',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProfileKycScreen(userId: userId))),
                ),
                _MenuTile(
                  icon: Icons.settings_outlined,
                  color: AppColors.textMuted,
                  title: 'Settings',
                  subtitle: 'Appearance, security, and account',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SettingsScreen(userId: userId))),
                ),
                _MenuTile(
                  icon: Icons.slideshow_outlined,
                  color: AppColors.accent,
                  title: 'View onboarding',
                  subtitle: 'Replay the intro walkthrough',
                  onTap: () async {
                    await OnboardingRepository().reset();
                    if (context.mounted) {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const OnboardingScreen()));
                    }
                  },
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    await AuthService().logout();
                    if (context.mounted) {
                      // Return to the reactive AuthGate → Welcome landing.
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
