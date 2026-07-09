import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_startup_service.dart';
import 'data/onboarding_repository.dart';

final onboardingRepositoryProvider =
    Provider<OnboardingRepository>((ref) => OnboardingRepository());

final appStartupServiceProvider = Provider<AppStartupService>((ref) =>
    AppStartupService(
        ref.read(onboardingRepositoryProvider), FirebaseAuth.instance));

/// Resolves (with logging) where the splash should route: onboarding vs app.
final startupRouteProvider = FutureProvider<StartupRoute>(
    (ref) => ref.read(appStartupServiceProvider).resolve());
