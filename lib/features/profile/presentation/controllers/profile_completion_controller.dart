import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/profile_providers.dart';
import '../../domain/profile_draft.dart';

/// Drives the Profile Completion submit button. `AsyncData` = idle/succeeded,
/// `AsyncLoading` = writing to Firestore, `AsyncError` = failed (UI shows the
/// friendly message and lets the user retry — the draft is untouched).
class ProfileCompletionController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> submit(String uid, ProfileDraft draft) async {
    state = const AsyncLoading();
    try {
      await ref.read(profileRepositoryProvider).completeProfile(uid, draft);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
      return false;
    }
  }
}

final profileCompletionControllerProvider =
    AutoDisposeAsyncNotifierProvider<ProfileCompletionController, void>(
        ProfileCompletionController.new);
