import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the first-run onboarding flag (`hasCompletedOnboarding`) in
/// SharedPreferences. Default is `false` (never onboarded).
class OnboardingRepository {
  static const _key = 'hasCompletedOnboarding';

  Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    debugPrint('SecureBank ▸ hasCompletedOnboarding set to true');
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    debugPrint('SecureBank ▸ onboarding flag reset');
  }
}
