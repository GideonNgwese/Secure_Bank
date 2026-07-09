/// Runtime configuration injected via `--dart-define` (never hardcode secrets).
///
/// Example run:
///   flutter run --dart-define=API_BASE_URL=https://api.securebank.app \
///     --dart-define=CLOUDINARY_CLOUD_NAME=securebank \
///     --dart-define=CLOUDINARY_UPLOAD_PRESET=securebank_unsigned
///
/// Only non-secret, client-safe values live here. Brevo keys, Cloudinary API
/// secret and Firebase Admin credentials stay on the backend.
class AppConfig {
  AppConfig._();

  /// Base URL of the secure backend that owns OTP + Cloudinary signing.
  static const String apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Cloudinary cloud name (public) + unsigned upload preset for direct client
  /// uploads. Signed uploads go through the backend instead.
  static const String cloudinaryCloudName =
      String.fromEnvironment('CLOUDINARY_CLOUD_NAME', defaultValue: '');
  static const String cloudinaryUploadPreset =
      String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET', defaultValue: '');

  /// Whether unverified email/password users are blocked until they verify.
  /// Turn off for testing if email delivery is unreliable:
  ///   flutter run --dart-define=ENFORCE_EMAIL_VERIFICATION=false
  static const bool enforceEmailVerification =
      bool.fromEnvironment('ENFORCE_EMAIL_VERIFICATION', defaultValue: true);

  /// Shows the Fraud Rule Tester under Settings → Developer, for quickly
  /// verifying risk-band classification against known amounts without
  /// writing real transactions. On by default (this is a demo/academic
  /// build); turn off for a "production" build:
  ///   flutter run --dart-define=FRAUD_TEST_MODE=false
  static const bool fraudTestModeEnabled =
      bool.fromEnvironment('FRAUD_TEST_MODE', defaultValue: true);

  static bool get hasApi => apiBaseUrl.isNotEmpty;
  static bool get hasCloudinary =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;
}
