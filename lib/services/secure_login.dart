import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Handles "Remember Me" credential storage and biometric (fingerprint) login.
///
/// Credentials are kept in flutter_secure_storage, which is backed by the
/// Android Keystore (encrypted at rest) — not SharedPreferences. This lets a
/// returning user unlock with a fingerprint instead of retyping their password.
/// (In a production bank this would use a short-lived refresh token rather than
/// the raw password, but for this academic prototype secure storage is enough.)
class SecureLogin {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _localAuth = LocalAuthentication();

  static const _kEmail = 'sl_email';
  static const _kPassword = 'sl_password';
  static const _kEnabled = 'sl_remember_enabled';

  Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kPassword, value: password);
    await _storage.write(key: _kEnabled, value: 'true');
  }

  Future<void> clear() async {
    await _storage.delete(key: _kEmail);
    await _storage.delete(key: _kPassword);
    await _storage.delete(key: _kEnabled);
  }

  Future<bool> isRemembered() async =>
      (await _storage.read(key: _kEnabled)) == 'true';

  Future<String?> savedEmail() => _storage.read(key: _kEmail);
  Future<String?> savedPassword() => _storage.read(key: _kPassword);

  /// True if the device can perform a biometric/credential check.
  /// `canCheckBiometrics` is the key signal (hardware present + enrolled);
  /// `getAvailableBiometrics` can return empty on some Android builds even when
  /// a fingerprint is enrolled, so we don't require it.
  Future<bool> canUseBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the system fingerprint/biometric dialog. Returns true on success.
  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Verify your identity to log in to SecureBank',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
