import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/notification_preferences_model.dart';
import 'email_api_service.dart';

/// High-level, typed entry point for every SecureBank transactional email —
/// the only class the rest of the app calls into. Every method:
///  1. Checks [NotificationPreferencesModel] for optional categories (skips
///     silently if disabled — security-critical events ignore preferences
///     entirely, see each method's `optional` value and the model's doc).
///  2. Pre-writes a `queued` `email_queue` doc (the durable audit trail,
///     survives even a total network failure on step 3).
///  3. Calls the secure backend's `/send-email` endpoint, which renders the
///     branded template and sends via Brevo — see `backend/templates/`.
///
/// Every call is fire-and-forget from the caller's point of view: a failure
/// anywhere in here is swallowed (logged into `email_queue.lastError` by the
/// backend) rather than thrown, so a flaky email can never break a banking
/// action like adding a transaction or resolving a fraud alert.
class EmailRepository {
  final FirebaseFirestore _db;
  final EmailApiService _api;
  EmailRepository({FirebaseFirestore? db, EmailApiService? api})
      : _db = db ?? FirebaseFirestore.instance,
        _api = api ?? EmailApiService();

  Future<NotificationPreferencesModel> _prefsFor(String userId) async {
    try {
      final snap =
          await _db.collection('notification_preferences').doc(userId).get();
      return snap.exists
          ? NotificationPreferencesModel.fromMap(snap.data()!)
          : const NotificationPreferencesModel();
    } catch (_) {
      return const NotificationPreferencesModel();
    }
  }

  Future<void> _send({
    required String eventType,
    required String userId,
    required String recipientEmail,
    String recipientName = '',
    Map<String, dynamic> templateData = const {},
    bool optional = true,
    bool Function(NotificationPreferencesModel)? categoryEnabled,
  }) async {
    if (recipientEmail.isEmpty) return;
    if (optional) {
      final prefs = await _prefsFor(userId);
      if (!prefs.emailEnabled) return;
      if (categoryEnabled != null && !categoryEnabled(prefs)) return;
    }

    final queueRef = _db.collection('email_queue').doc();
    try {
      await queueRef.set({
        'eventType': eventType,
        'userId': userId,
        'recipientEmail': recipientEmail,
        'recipientName': recipientName,
        'status': 'queued',
        'attempts': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      return; // offline / rules mismatch — nothing more we can do quietly
    }

    await _api.sendEmail(
      eventType: eventType,
      recipientEmail: recipientEmail,
      recipientName: recipientName,
      templateData: templateData,
      targetUserId: userId,
      queueId: queueRef.id,
    );
  }

  // ---------------- Security-critical (never preference-gated) ----------------

  Future<void> accountCreated(
          {required String userId, required String email, required String name}) =>
      _send(
          eventType: 'account_created',
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          optional: false);

  Future<void> googleSignIn(
          {required String userId,
          required String email,
          required String name,
          String? deviceInfo}) =>
      _send(
          eventType: 'google_sign_in',
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          templateData: {
            'deviceInfo': deviceInfo,
            'time': DateTime.now().toIso8601String(),
          },
          optional: false);

  Future<void> passwordChanged(
          {required String userId, required String email, required String name}) =>
      _send(
          eventType: 'password_changed',
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          templateData: {'time': DateTime.now().toIso8601String()},
          optional: false);

  Future<void> newDeviceLogin(
          {required String userId,
          required String email,
          required String name,
          String? deviceInfo,
          String? location}) =>
      _send(
          eventType: 'new_device_login',
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          templateData: {
            'deviceInfo': deviceInfo,
            'location': location,
            'time': DateTime.now().toIso8601String(),
          },
          optional: false);

  Future<void> accountStatusChanged(
          {required String userId,
          required String email,
          required String name,
          required bool suspended,
          String? reason}) =>
      _send(
          eventType: suspended ? 'account_suspended' : 'account_reactivated',
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          templateData: {'reason': reason},
          optional: false);

  Future<void> fraudDetected({
    required String userId,
    required String email,
    required String name,
    required String riskLevel,
    required int riskScore,
    required String reason,
    required double amount,
    String? referenceNumber,
  }) =>
      _send(
          eventType: 'fraud_detected',
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          templateData: {
            'riskLevel': riskLevel,
            'riskScore': riskScore,
            'reason': reason,
            'amount': amount,
            'referenceNumber': referenceNumber,
            'time': DateTime.now().toIso8601String(),
          },
          optional: false);

  Future<void> fraudResolution({
    required String userId,
    required String email,
    required String name,
    required bool approved,
    required double amount,
    String? referenceNumber,
  }) =>
      _send(
          eventType: approved ? 'fraud_approved' : 'fraud_declined',
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          templateData: {
            'amount': amount,
            'referenceNumber': referenceNumber,
            'time': DateTime.now().toIso8601String(),
          },
          optional: false);

  // ---------------- Optional (preference-gated) ----------------

  Future<void> transactionReceipt({
    required String userId,
    required String email,
    required String name,
    required String type, // 'cash_in' | 'cash_out' | 'transfer'
    required double amount,
    String? category,
    String? merchant,
    String? account,
    String? referenceNumber,
  }) =>
      _send(
          eventType: type,
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          templateData: {
            'amount': amount,
            'category': category,
            'merchant': merchant,
            'account': account,
            'referenceNumber': referenceNumber,
            'time': DateTime.now().toIso8601String(),
          },
          categoryEnabled: (p) => p.transactionReceipts);

  Future<void> budgetExceeded({
    required String userId,
    required String email,
    required String name,
    required String budgetName,
    String? category,
    required double spent,
    required double limit,
    required int percentUsed,
  }) =>
      _send(
          eventType: 'budget_exceeded',
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          templateData: {
            'budgetName': budgetName,
            'category': category,
            'spent': spent,
            'limit': limit,
            'percentUsed': percentUsed,
          },
          categoryEnabled: (p) => p.budgetReminders);

  Future<void> kycStatus({
    required String userId,
    required String email,
    required String name,
    required bool approved,
    String? notes,
  }) =>
      _send(
          eventType: approved ? 'kyc_approved' : 'kyc_rejected',
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          templateData: {'notes': notes},
          categoryEnabled: (p) => p.kycUpdates);

  Future<void> adminAnnouncement({
    required String userId,
    required String email,
    required String name,
    required String title,
    required String body,
    required String priority,
  }) =>
      _send(
          eventType: 'admin_announcement',
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          templateData: {'title': title, 'body': body, 'priority': priority},
          categoryEnabled: (p) => p.adminAnnouncements);

  Future<void> monthlySummary({
    required String userId,
    required String email,
    required String name,
    required Map<String, dynamic> summary,
  }) =>
      _send(
          eventType: 'monthly_summary',
          userId: userId,
          recipientEmail: email,
          recipientName: name,
          templateData: summary,
          categoryEnabled: (p) => p.monthlySummary);
}
