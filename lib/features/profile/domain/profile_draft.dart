import 'profile_fields.dart';

/// In-progress form state for the Profile Completion screen. Immutable value
/// object — the controller replaces it wholesale on every field edit.
class ProfileDraft {
  final String fullName;
  final String phone;
  final String gender;
  final DateTime? dateOfBirth;
  final String region;
  final String city;
  final String occupation;
  final String preferredCurrency;
  final String preferredLanguage;
  final String photoUrl;

  const ProfileDraft({
    this.fullName = '',
    this.phone = '',
    this.gender = '',
    this.dateOfBirth,
    this.region = '',
    this.city = '',
    this.occupation = '',
    this.preferredCurrency = 'FCFA',
    this.preferredLanguage = 'English',
    this.photoUrl = '',
  });

  /// Seeds the draft from whatever is already on the user's Firestore doc
  /// (name/phone from registration, sensible defaults for the rest).
  factory ProfileDraft.prefill({
    required String fullName,
    required String phone,
    String? gender,
    DateTime? dateOfBirth,
    String? region,
    String? city,
    String? occupation,
    String? preferredCurrency,
    String? preferredLanguage,
    String? photoUrl,
  }) =>
      ProfileDraft(
        fullName: fullName,
        phone: phone,
        gender: (gender ?? '').isNotEmpty ? gender! : '',
        dateOfBirth: dateOfBirth,
        region: (region ?? '').isNotEmpty ? region! : '',
        city: city ?? '',
        occupation: (occupation ?? '').isNotEmpty ? occupation! : '',
        preferredCurrency: (preferredCurrency ?? '').isNotEmpty
            ? preferredCurrency!
            : ProfileFields.currencies.first,
        preferredLanguage: (preferredLanguage ?? '').isNotEmpty
            ? preferredLanguage!
            : ProfileFields.languages.first,
        photoUrl: photoUrl ?? '',
      );

  ProfileDraft copyWith({
    String? fullName,
    String? phone,
    String? gender,
    DateTime? Function()? dateOfBirth,
    String? region,
    String? city,
    String? occupation,
    String? preferredCurrency,
    String? preferredLanguage,
    String? photoUrl,
  }) =>
      ProfileDraft(
        fullName: fullName ?? this.fullName,
        phone: phone ?? this.phone,
        gender: gender ?? this.gender,
        dateOfBirth: dateOfBirth != null ? dateOfBirth() : this.dateOfBirth,
        region: region ?? this.region,
        city: city ?? this.city,
        occupation: occupation ?? this.occupation,
        preferredCurrency: preferredCurrency ?? this.preferredCurrency,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        photoUrl: photoUrl ?? this.photoUrl,
      );
}
