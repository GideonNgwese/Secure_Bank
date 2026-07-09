import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

/// Talks to the secure backend's authenticated `/send-email` endpoint (see
/// `backend/server.js` and `backend/templates/`) — the same backend
/// `OtpApiService` already uses for password-reset/verification codes, just
/// with a Firebase ID token attached since this endpoint sends on behalf of
/// a specific signed-in user. The Brevo key and Admin credentials live only
/// on that backend; this client never sees them.
///
/// Deliberately swallows every failure rather than throwing: sending an
/// email must never interrupt the banking action that triggered it (adding
/// a transaction, resolving a fraud alert, etc.) — see [EmailRepository].
class EmailApiService {
  final http.Client _client;
  EmailApiService([http.Client? client]) : _client = client ?? http.Client();

  Future<void> sendEmail({
    required String eventType,
    required String recipientEmail,
    String recipientName = '',
    Map<String, dynamic> templateData = const {},
    String? targetUserId,
    String? queueId,
  }) async {
    if (!AppConfig.hasApi) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final idToken = await user.getIdToken();
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/send-email');
      await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'eventType': eventType,
              'recipientEmail': recipientEmail,
              'recipientName': recipientName,
              'templateData': templateData,
              if (targetUserId != null) 'targetUserId': targetUserId,
              if (queueId != null) 'queueId': queueId,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // Best-effort by design — the queued Firestore doc (written before
      // this call) is the durable record; a transient network failure here
      // just means it stays 'queued' instead of progressing, which is
      // visible to whoever checks delivery status, not a thrown exception.
    }
  }
}
