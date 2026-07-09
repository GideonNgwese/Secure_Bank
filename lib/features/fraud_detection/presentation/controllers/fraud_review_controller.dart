import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../models/transaction_model.dart';
import '../../../../services/firestore_service.dart';
import '../../../email/data/email_providers.dart';
import '../../../transactions/data/transaction_providers.dart';
import '../../data/fraud_detection_providers.dart';

/// Drives the Fraud Review Screen's Approve / Decline / Review Later actions.
/// Reuses [TransactionRepository]/[FraudDetectionRepository] for every write
/// — this controller only orchestrates which of their existing methods run
/// and in what order, it never touches Firestore directly except for the
/// audit-log entry (`FirestoreService.logReviewActivity`, itself a thin
/// addition next to the existing `logActivity`).
class FraudReviewController extends AutoDisposeAsyncNotifier<void> {
  final _fs = FirestoreService();

  @override
  FutureOr<void> build() {}

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e is AppException ? e : mapError(e), st);
      return false;
    }
  }

  /// Approve: transaction -> Approved (now counts toward balances/budgets
  /// exactly like Completed, via `TransactionModel.isCompleted`), fraud_alert
  /// -> approved, notification marked read/resolved. This is self-attestation
  /// — the account owner confirming their own transaction, so `reviewedBy` is
  /// their own uid.
  Future<bool> approve(TransactionModel tx) => _run(() async {
        await ref.read(transactionRepositoryProvider).resolveReview(
              tx: tx,
              status: 'Approved',
              reviewedBy: tx.userId,
            );
        if (tx.fraudAlertId != null) {
          await ref.read(fraudDetectionRepositoryProvider).resolveAlert(
                tx.fraudAlertId!,
                alertStatus: 'approved',
                resolution: 'approved',
              );
        }
        await _fs.logReviewActivity(
          userId: tx.userId,
          transactionId: tx.id,
          action: 'Approved flagged transaction (${tx.riskLevel} risk)',
          device: defaultTargetPlatform.name,
        );
        _sendResolutionEmail(tx, approved: true);
      });

  /// Decline: transaction -> Declined (never counts toward balances — stays
  /// blocked), fraud_alert -> confirmed_fraud, plus a second "your
  /// transaction has been blocked" security notification.
  Future<bool> decline(TransactionModel tx) => _run(() async {
        await ref.read(transactionRepositoryProvider).resolveReview(
              tx: tx,
              status: 'Declined',
              reviewedBy: tx.userId,
            );
        if (tx.fraudAlertId != null) {
          final fraudRepo = ref.read(fraudDetectionRepositoryProvider);
          await fraudRepo.resolveAlert(
            tx.fraudAlertId!,
            alertStatus: 'confirmed_fraud',
            resolution: 'confirmed_fraud',
          );
          await fraudRepo.createSecurityBlockNotification(
            userId: tx.userId,
            transactionId: tx.id,
          );
        }
        await _fs.logReviewActivity(
          userId: tx.userId,
          transactionId: tx.id,
          action:
              'Declined flagged transaction (${tx.riskLevel} risk) — blocked',
          device: defaultTargetPlatform.name,
        );
        _sendResolutionEmail(tx, approved: false);
      });

  void _sendResolutionEmail(TransactionModel tx, {required bool approved}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    ref.read(emailRepositoryProvider).fraudResolution(
          userId: tx.userId,
          email: user!.email!,
          name: user.displayName ?? '',
          approved: approved,
          amount: tx.amount.abs(),
          referenceNumber: tx.id,
        );
  }

  /// Review Later: no transaction/alert state changes — status remains
  /// Pending Review. Only marks the notification as seen (not dismissed, and
  /// actionRequired stays true) so it still surfaces everywhere pending
  /// reviews are counted, while recording that the user deferred it.
  Future<bool> reviewLater(TransactionModel tx) => _run(() async {
        if (tx.fraudAlertId != null) {
          await ref
              .read(fraudDetectionRepositoryProvider)
              .setNotificationStatus(tx.fraudAlertId!, read: true);
        }
        await _fs.logReviewActivity(
          userId: tx.userId,
          transactionId: tx.id,
          action:
              'Deferred review of flagged transaction (${tx.riskLevel} risk)',
          device: defaultTargetPlatform.name,
        );
      });
}

final fraudReviewControllerProvider =
    AutoDisposeAsyncNotifierProvider<FraudReviewController, void>(
        FraudReviewController.new);
