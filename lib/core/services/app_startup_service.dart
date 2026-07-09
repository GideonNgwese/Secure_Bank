import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../features/onboarding/data/onboarding_repository.dart';

/// Where the splash routes after its animation.
/// [onboarding] → first-run walkthrough; [app] → the reactive AuthGate
/// (which then shows Dashboard when logged in, or the auth landing otherwise).
enum StartupRoute { onboarding, app }

/// Decides the startup destination from onboarding + auth state, with logging.
/// Keeps this decision out of the widgets.
class AppStartupService {
  final OnboardingRepository _onboarding;
  final FirebaseAuth _auth;
  AppStartupService(this._onboarding, this._auth);

  Future<StartupRoute> resolve() async {
    final completed = await _onboarding.isCompleted();
    debugPrint('SecureBank ▸ Onboarding completed: $completed');

    if (!completed) {
      debugPrint('SecureBank ▸ Opening onboarding');
      return StartupRoute.onboarding;
    }

    final user = _auth.currentUser;
    debugPrint('SecureBank ▸ Checking authentication…');
    if (user != null) {
      debugPrint('SecureBank ▸ Authenticated (${user.uid}) → Dashboard');
    } else {
      debugPrint('SecureBank ▸ Not authenticated → Login');
    }
    return StartupRoute.app;
  }
}
