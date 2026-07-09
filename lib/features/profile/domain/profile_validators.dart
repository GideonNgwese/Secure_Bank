/// Pure, reusable validators for the Profile Completion form. Kept separate
/// from `features/auth/domain/validators.dart` because this step enforces
/// stricter, Cameroon-specific rules (e.g. phone format, minimum age).
class ProfileValidators {
  ProfileValidators._();

  /// Cameroon mobile numbers: 9 digits starting with 6, optionally prefixed
  /// with +237 or 237 (e.g. 675 123 456, +237 675123456, 237675123456).
  static final RegExp _cameroonPhone = RegExp(r'^(?:\+?237)?6\d{8}$');

  static String? fullName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Full name is required';
    if (s.length < 3) return 'Enter at least 3 characters';
    return null;
  }

  static String? phone(String? v) {
    final s = (v ?? '').trim().replaceAll(RegExp(r'[\s-]'), '');
    if (s.isEmpty) return 'Phone number is required';
    if (!_cameroonPhone.hasMatch(s)) {
      return 'Enter a valid Cameroon number (e.g. 6XX XXX XXX)';
    }
    return null;
  }

  static String? required(String? v, String label) {
    if ((v ?? '').trim().isEmpty) return '$label is required';
    return null;
  }

  static String? dateOfBirth(DateTime? v) {
    if (v == null) return 'Date of birth is required';
    final today = DateTime.now();
    var age = today.year - v.year;
    if (today.month < v.month ||
        (today.month == v.month && today.day < v.day)) {
      age--;
    }
    if (v.isAfter(today)) return 'Date of birth cannot be in the future';
    if (age < 18) return 'You must be at least 18 years old';
    return null;
  }
}
