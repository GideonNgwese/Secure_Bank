import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/premium_header.dart';
import '../../../../models/notification_preferences_model.dart';
import '../../../../screens/auth/forgot_password_screen.dart';
import '../../../../screens/profile/profile_kyc_screen.dart';
import '../../../../services/auth_service.dart';
import '../../../../utils/constants.dart';
import '../../../email/data/email_providers.dart';
import '../../../fraud_detection/presentation/screens/fraud_center_screen.dart';
import '../../../fraud_detection/presentation/screens/fraud_test_mode_screen.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';

/// App preferences and security — the real destination the header's gear
/// icon points to (it used to just switch bottom-nav tabs to More). Every
/// control here is wired to something that actually exists: the theme mode
/// this app already ships with, the Notifications/Fraud Center/Profile
/// screens, and the working password-reset flow — nothing here is a
/// placeholder toggle with no backing state.
class SettingsScreen extends ConsumerStatefulWidget {
  final String userId;
  const SettingsScreen({super.key, required this.userId});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          PremiumHeader(
            userId: widget.userId,
            title: 'Settings',
            scrollController: _scrollController,
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                FadeSlideIn(
                  child: _Section(
                    title: 'Appearance',
                    children: [
                      _ThemeModeSelector(
                        current: themeMode,
                        onChanged: (mode) =>
                            ref.read(themeModeProvider.notifier).state = mode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FadeSlideIn(
                  duration: const Duration(milliseconds: 450),
                  child: _Section(
                    title: 'Notifications',
                    children: [
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: 'Manage notifications',
                        subtitle: 'Fraud alerts, budget alerts, and insights',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => NotificationsScreen(
                                    userId: widget.userId))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FadeSlideIn(
                  duration: const Duration(milliseconds: 475),
                  child: _EmailPreferencesSection(userId: widget.userId),
                ),
                const SizedBox(height: 20),
                FadeSlideIn(
                  duration: const Duration(milliseconds: 500),
                  child: _Section(
                    title: 'Security',
                    children: [
                      _SettingsTile(
                        icon: Icons.shield_outlined,
                        title: 'Security Center',
                        subtitle: 'Security score, risk analytics',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    FraudCenterScreen(userId: widget.userId))),
                      ),
                      _SettingsTile(
                        icon: Icons.badge_outlined,
                        title: 'Profile & KYC',
                        subtitle: 'Identity verification status',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    ProfileKycScreen(userId: widget.userId))),
                      ),
                      _SettingsTile(
                        icon: Icons.lock_outline,
                        title: 'Change password',
                        subtitle: 'Reset your password by email',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen())),
                      ),
                    ],
                  ),
                ),
                if (AppConfig.fraudTestModeEnabled) ...[
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    duration: const Duration(milliseconds: 525),
                    child: _Section(
                      title: 'Developer',
                      children: [
                        _SettingsTile(
                          icon: Icons.science_outlined,
                          title: 'Fraud Rule Tester',
                          subtitle: 'Verify risk-band classification by amount',
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const FraudTestModeScreen())),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FadeSlideIn(
                  duration: const Duration(milliseconds: 550),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await AuthService().logout();
                        if (context.mounted) {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  const Divider(height: 1, indent: 56),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

/// Email/push/in-app notification preferences. Security-critical email
/// (account created, password changed, fraud alerts, account suspended/
/// reactivated, new-device sign-in) always sends regardless of these
/// toggles — see [EmailRepository] doc — so only the informational
/// categories are listed here.
class _EmailPreferencesSection extends ConsumerWidget {
  final String userId;
  const _EmailPreferencesSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPreferencesProvider(userId));
    final prefs = prefsAsync.valueOrNull ?? const NotificationPreferencesModel();

    Future<void> update(NotificationPreferencesModel next) => ref
        .read(notificationPreferencesRepositoryProvider)
        .update(userId, next);

    return _Section(
      title: 'Email Preferences',
      children: [
        _PrefSwitch(
          title: 'Email notifications',
          subtitle: 'Master switch for informational email below',
          value: prefs.emailEnabled,
          onChanged: (v) => update(prefs.copyWith(emailEnabled: v)),
        ),
        _PrefSwitch(
          title: 'Push notifications',
          subtitle: 'On-device alerts (coming soon)',
          value: prefs.pushEnabled,
          onChanged: (v) => update(prefs.copyWith(pushEnabled: v)),
        ),
        _PrefSwitch(
          title: 'In-app notifications',
          subtitle: 'Notifications inbox inside the app',
          value: prefs.inAppEnabled,
          onChanged: (v) => update(prefs.copyWith(inAppEnabled: v)),
        ),
        _PrefSwitch(
          title: 'Transaction receipts',
          subtitle: 'Email confirmation for cash in/out and transfers',
          value: prefs.transactionReceipts,
          enabled: prefs.emailEnabled,
          onChanged: (v) => update(prefs.copyWith(transactionReceipts: v)),
        ),
        _PrefSwitch(
          title: 'Budget reminders',
          subtitle: 'Email when a budget limit is reached',
          value: prefs.budgetReminders,
          enabled: prefs.emailEnabled,
          onChanged: (v) => update(prefs.copyWith(budgetReminders: v)),
        ),
        _PrefSwitch(
          title: 'Monthly summary',
          subtitle: 'A recap of income, spending, and security each month',
          value: prefs.monthlySummary,
          enabled: prefs.emailEnabled,
          onChanged: (v) => update(prefs.copyWith(monthlySummary: v)),
        ),
        _PrefSwitch(
          title: 'Admin announcements',
          subtitle: 'General announcements from SecureBank',
          value: prefs.adminAnnouncements,
          enabled: prefs.emailEnabled,
          onChanged: (v) => update(prefs.copyWith(adminAnnouncements: v)),
        ),
        _PrefSwitch(
          title: 'KYC updates',
          subtitle: 'Verification approved/rejected notices',
          value: prefs.kycUpdates,
          enabled: prefs.emailEnabled,
          onChanged: (v) => update(prefs.copyWith(kycUpdates: v)),
        ),
      ],
    );
  }
}

class _PrefSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _PrefSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        value: value,
        onChanged: enabled ? onChanged : null,
        activeThumbColor: AppColors.primary,
      ),
    );
  }
}

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeModeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Theme',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Choose how SecureBank looks on this device',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined, size: 16),
                  label: Text('Light')),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined, size: 16),
                  label: Text('Dark')),
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.smartphone_outlined, size: 16),
                  label: Text('System')),
            ],
            selected: {current},
            onSelectionChanged: (s) => onChanged(s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              side: WidgetStatePropertyAll(
                  BorderSide(color: AppColors.primary.withValues(alpha: 0.3))),
            ),
          ),
        ],
      ),
    );
  }
}
