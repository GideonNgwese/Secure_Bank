/// Pure, reusable form validators. UI passes these to `TextFormField.validator`
/// and can also call them live (onChanged) for realtime feedback.
class Validators {
  Validators._();

  static final RegExp _email =
      RegExp(r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$');
  static final RegExp _phone = RegExp(r'^\+?[0-9]{7,15}$');
  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _special = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]/\\+=;~`]');

  static String? fullName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Full name is required';
    if (s.length < 2) return 'Enter your full name';
    return null;
  }

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    if (!_email.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? v) {
    final s = (v ?? '').trim().replaceAll(' ', '');
    if (s.isEmpty) return 'Phone number is required';
    if (!_phone.hasMatch(s)) return 'Enter a valid phone number';
    return null;
  }

  static String? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    if (s.length < 8) return 'At least 8 characters';
    if (!_upper.hasMatch(s)) return 'Add an uppercase letter';
    if (!_lower.hasMatch(s)) return 'Add a lowercase letter';
    if (!_digit.hasMatch(s)) return 'Add a number';
    if (!_special.hasMatch(s)) return 'Add a special character';
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if ((v ?? '').isEmpty) return 'Confirm your password';
    if (v != original) return 'Passwords do not match';
    return null;
  }

  /// Password strength 0..4 (length≥8, upper, lower, digit, special).
  static int passwordStrength(String v) {
    if (v.isEmpty) return 0;
    var score = 0;
    if (v.length >= 8) score++;
    if (_upper.hasMatch(v) && _lower.hasMatch(v)) score++;
    if (_digit.hasMatch(v)) score++;
    if (_special.hasMatch(v)) score++;
    return score;
  }

  static String strengthLabel(int score) {
    switch (score) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      default:
        return 'Strong';
    }
  }
}
