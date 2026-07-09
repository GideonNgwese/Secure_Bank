import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/profile_draft.dart';

/// Holds the in-progress Profile Completion form. A plain [Notifier] (not
/// async) since this is local edit state — the only Firestore write happens
/// once, on submit, via [ProfileCompletionController].
class ProfileDraftNotifier extends AutoDisposeNotifier<ProfileDraft> {
  @override
  ProfileDraft build() => const ProfileDraft();

  /// One-time seed from the user's existing Firestore doc (called by the
  /// screen right after first build, before the user has typed anything).
  void seed(ProfileDraft draft) => state = draft;

  void setFullName(String v) => state = state.copyWith(fullName: v);
  void setPhone(String v) => state = state.copyWith(phone: v);
  void setGender(String v) => state = state.copyWith(gender: v);
  void setDateOfBirth(DateTime v) =>
      state = state.copyWith(dateOfBirth: () => v);
  void setRegion(String v) => state = state.copyWith(region: v);
  void setCity(String v) => state = state.copyWith(city: v);
  void setOccupation(String v) => state = state.copyWith(occupation: v);
  void setPreferredCurrency(String v) =>
      state = state.copyWith(preferredCurrency: v);
  void setPreferredLanguage(String v) =>
      state = state.copyWith(preferredLanguage: v);
  void setPhotoUrl(String v) => state = state.copyWith(photoUrl: v);
}

final profileDraftProvider =
    AutoDisposeNotifierProvider<ProfileDraftNotifier, ProfileDraft>(
        ProfileDraftNotifier.new);
