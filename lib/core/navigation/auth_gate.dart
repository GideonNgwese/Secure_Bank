import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/domain/auth_user.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/controllers/email_verification_controller.dart';
import '../../features/admin/presentation/screens/admin_shell.dart';
import '../../features/profile/presentation/profile_completion_screen.dart';
import '../../screens/auth/welcome_screen.dart';
import '../../screens/auth/verify_email_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../utils/constants.dart';

/// Reactive routing based on Firebase auth state:
/// signed-out → Welcome; signed-in but unverified email → Verify Email;
/// verified but profile incomplete → Profile Completion (once); suspended →
/// a logout-only notice; admin → the Admin Portal ([AdminShell]); otherwise
/// the customer's [CustomerShell]. Reached after the splash / onboarding, and
/// the sole owner of this decision tree — no other screen re-derives it.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateChangesProvider);
    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const WelcomeScreen(),
      data: (user) {
        if (user == null) return const WelcomeScreen();
        final verified = ref.watch(emailVerificationProvider).maybeWhen(
              data: (v) => v,
              orElse: () => user.emailVerified,
            );
        if (AppConfig.enforceEmailVerification && !verified) {
          return const VerifyEmailScreen();
        }

        final profileAsync = ref.watch(currentProfileStreamProvider);
        return profileAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          // A transient error reading the profile shouldn't lock the user
          // out silently — offer a retry rather than guessing their role.
          error: (_, __) => _ProfileLoadError(
              onRetry: () => ref.invalidate(currentProfileStreamProvider)),
          data: (profile) {
            // profile == null briefly while the Firestore doc is still being
            // created right after sign-up — keep waiting on the live stream.
            if (profile == null) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }
            if (!profile.isAdmin && !profile.profileCompleted) {
              return ProfileCompletionScreen(initial: profile);
            }
            if (profile.isSuspended) {
              return _SuspendedAccountScreen(profile: profile);
            }
            if (profile.isAdmin) {
              return AdminShell(admin: profile);
            }
            return CustomerShell(profile: profile);
          },
        );
      },
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  final VoidCallback onRetry;
  const _ProfileLoadError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: AppColors.textMuted, size: 48),
              const SizedBox(height: 12),
              const Text("Couldn't load your profile.",
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuspendedAccountScreen extends ConsumerWidget {
  final AuthUser profile;
  const _SuspendedAccountScreen({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, color: AppColors.danger, size: 48),
              const SizedBox(height: 12),
              const Text('Your account has been suspended.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
                child: const Text('Logout'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
