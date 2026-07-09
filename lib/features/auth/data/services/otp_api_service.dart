import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';

/// Talks to the secure backend that generates OTPs, sends them via Brevo, and
/// (using the Firebase Admin SDK) verifies codes / resets passwords / marks
/// emails verified. The Brevo key and Admin credentials live ONLY on the
/// backend — this client just calls REST endpoints.
///
/// Endpoints (see `backend/`):
///   POST /send-reset-code        { email }
///   POST /verify-reset-code      { email, code }
///   POST /reset-password         { email, code, newPassword }
///   POST /send-verification-code { email }
///   POST /verify-email-code      { email, code }
class OtpApiService {
  final http.Client _client;
  OtpApiService([http.Client? client]) : _client = client ?? http.Client();

  // ---- Password reset ----
  Future<void> sendResetCode(String email) =>
      _post('/send-reset-code', {'email': email.trim()});

  Future<void> verifyResetCode(String email, String code) =>
      _post('/verify-reset-code', {'email': email.trim(), 'code': code});

  Future<void> resetPassword(String email, String code, String newPassword) =>
      _post('/reset-password',
          {'email': email.trim(), 'code': code, 'newPassword': newPassword});

  // ---- Email verification (OTP via Brevo) ----
  Future<void> sendVerificationCode(String email) =>
      _post('/send-verification-code', {'email': email.trim()});

  Future<void> verifyEmailCode(String email, String code) =>
      _post('/verify-email-code', {'email': email.trim(), 'code': code});

  Future<void> _post(String path, Map<String, dynamic> body) async {
    if (!AppConfig.hasApi) {
      throw const ServerException(
          'Email service is not configured yet. Please try again later.');
    }
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final res = await _client
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    // Surface the backend's friendly message when present.
    String message = 'Request failed. Please try again.';
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && (decoded['message'] ?? decoded['error']) != null) {
        message = (decoded['message'] ?? decoded['error']).toString();
      }
    } catch (_) {/* non-JSON body */}

    if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 422) {
      throw AuthException(message);
    }
    if (res.statusCode == 429) {
      throw const AuthException(
          'Too many attempts. Please wait a moment and try again.');
    }
    throw ServerException(message);
  }
}
