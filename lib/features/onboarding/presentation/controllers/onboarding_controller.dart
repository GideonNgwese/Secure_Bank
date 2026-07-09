import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../onboarding_providers.dart';

/// Holds the current onboarding page and owns the completion side-effect,
/// keeping that business logic out of the widget.
class OnboardingController extends AutoDisposeNotifier<int> {
  @override
  int build() => 0;

  void onPageChanged(int index) => state = index;

  bool get isLastPage => state >= 2;

  Future<void> complete() =>
      ref.read(onboardingRepositoryProvider).complete();
}

final onboardingControllerProvider =
    AutoDisposeNotifierProvider<OnboardingController, int>(
        OnboardingController.new);
