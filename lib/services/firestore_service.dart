import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../features/auth/domain/auth_user.dart';
import '../features/fraud_detection/data/services/fraud_analysis_service.dart';
import '../features/fraud_detection/domain/fraud_signal.dart';
import '../features/fraud_detection/domain/risk_level.dart';
import '../models/account_model.dart';
import '../models/admin_notification_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/fraud_alert_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../models/kyc_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FraudAnalysisService _fraud = FraudAnalysisService();
  final _uuid = const Uuid();

  // ---------------- ACCOUNTS ----------------

  Stream<List<AccountModel>> streamAccounts(String userId) {
    return _db
        .collection('accounts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => AccountModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> addAccount(AccountModel account) async {
    await _db.collection('accounts').doc(account.id).set(account.toMap());
    await logActivity(
        account.userId, 'Created account: ${account.accountName}');
  }

  Future<void> updateAccount(AccountModel account) {
    return _db.collection('accounts').doc(account.id).update(account.toMap());
  }

  Future<void> deleteAccount(String id) {
    return _db.collection('accounts').doc(id).delete();
  }

  // ---------------- TRANSACTIONS ----------------

  /// One-shot fetch of a user's transactions (used by CSV import for
  /// duplicate detection). Avoids the orderBy composite-index requirement.
  Future<List<TransactionModel>> getTransactions(String userId) async {
    final snap = await _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .get();
    return snap.docs
        .map((d) => TransactionModel.fromMap(d.id, d.data()))
        .toList();
  }

  Stream<List<TransactionModel>> streamTransactions(String userId) {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('transactionDate', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => TransactionModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Live single-transaction stream by id — used by the Fraud Review Screen,
  /// which needs to reflect an Approve/Decline instantly regardless of
  /// whether that transaction happens to be within the paginated list's
  /// current page size.
  Stream<TransactionModel?> streamTransactionById(String id) {
    return _db.collection('transactions').doc(id).snapshots().map(
        (d) => d.exists ? TransactionModel.fromMap(d.id, d.data()!) : null);
  }

  /// Same as [streamTransactions] but bounded to the most recent [limit]
  /// documents — an efficient, indexed query for the transactions list,
  /// which grows the limit on "load more" instead of fetching everything.
  Stream<List<TransactionModel>> streamTransactionsLimited(String userId,
      {required int limit}) {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('transactionDate', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs
            .map((d) => TransactionModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Adds a transaction (Income/Expense/Refund/Adjustment — not Transfer,
  /// which is created as a linked pair via [addTransfer]), running it through
  /// the fraud-risk scoring engine first.
  Future<TransactionModel> addTransaction({
    required String userId,
    required String accountId,
    required String type,
    required String category,
    required double amount,
    String title = '',
    required String description,
    String currency = 'FCFA',
    String paymentMethod = '',
    String merchant = '',
    String location = '',
    String receiptUrl = '',
    String status = 'Completed',
    required DateTime transactionDate,
    bool simulateNewDevice = false,
  }) async {
    final id = _uuid.v4();
    final risk = await _fraud.analyzeAndRecord(
      userId: userId,
      transactionId: id,
      candidate: FraudCandidate(
        accountId: accountId,
        type: type,
        category: category,
        amount: amount,
        description: description,
        merchant: merchant,
        paymentMethod: paymentMethod,
        transactionDate: transactionDate,
        simulateNewDevice: simulateNewDevice,
      ),
    );

    final now = DateTime.now();
    // Fraud Review Workflow: a Medium+ risk transaction is held for review
    // instead of completing automatically — the fraud engine's own
    // score/level (computed above, untouched) is the only thing deciding
    // this; Low risk keeps flowing through with whatever status the caller
    // passed in, exactly as it always has.
    final isFlagged = risk.level != RiskLevel.low;
    final effectiveStatus = isFlagged ? 'Pending Review' : status;
    final tx = TransactionModel(
      id: id,
      userId: userId,
      accountId: accountId,
      type: type,
      category: category,
      amount: amount,
      title: title,
      description: description,
      currency: currency,
      paymentMethod: paymentMethod,
      merchant: merchant,
      location: location,
      receiptUrl: receiptUrl,
      status: effectiveStatus,
      transactionDate: transactionDate,
      riskScore: risk.score,
      riskLevel: risk.level.label,
      createdAt: now,
      updatedAt: now,
      // fraud_alerts docs use the transactionId as their deterministic id
      // (see FraudDetectionRepository.recordAlert), so it's already known.
      fraudAlertId: isFlagged ? id : null,
    );

    await _db.collection('transactions').doc(tx.id).set(tx.toMap());

    await checkBudgetAfterTransaction(userId, category, transactionDate);
    await logActivity(
        userId, 'Added $type of ${amount.toStringAsFixed(0)} FCFA ($category)');

    return tx;
  }

  /// Edits an existing non-transfer transaction: re-scores it for fraud risk
  /// (excluding itself from the history) and rewrites the record. Always
  /// writes the full field set the caller provides (no partial patching), so
  /// callers must pass the complete, already-edited state.
  Future<TransactionModel> updateTransaction({
    required TransactionModel original,
    required String accountId,
    required String type,
    required String category,
    required double amount,
    String title = '',
    required String description,
    String currency = 'FCFA',
    String paymentMethod = '',
    String merchant = '',
    String location = '',
    String receiptUrl = '',
    String status = 'Completed',
    required DateTime transactionDate,
    bool simulateNewDevice = false,
  }) async {
    final risk = await _fraud.analyzeAndRecord(
      userId: original.userId,
      transactionId: original.id,
      candidate: FraudCandidate(
        accountId: accountId,
        type: type,
        category: category,
        amount: amount,
        description: description,
        merchant: merchant,
        paymentMethod: paymentMethod,
        transactionDate: transactionDate,
        simulateNewDevice: simulateNewDevice,
      ),
      excludeId: original.id,
    );

    // Same Fraud Review Workflow gate as addTransaction: if the edit still
    // (or newly) scores Medium+, the transaction goes back to Pending Review
    // for fresh sign-off rather than trusting a review made against the
    // pre-edit details — clearing any prior reviewedAt/reviewedBy.
    final isFlagged = risk.level != RiskLevel.low;
    final effectiveStatus = isFlagged ? 'Pending Review' : status;
    final updated = TransactionModel(
      id: original.id,
      userId: original.userId,
      accountId: accountId,
      type: type,
      category: category,
      amount: amount,
      title: title,
      description: description,
      currency: currency,
      paymentMethod: paymentMethod,
      merchant: merchant,
      location: location,
      receiptUrl: receiptUrl,
      status: effectiveStatus,
      transactionDate: transactionDate,
      riskScore: risk.score,
      riskLevel: risk.level.label,
      linkedTransferId: original.linkedTransferId,
      createdAt: original.createdAt,
      updatedAt: DateTime.now(),
      reviewedAt: isFlagged ? null : original.reviewedAt,
      reviewedBy: isFlagged ? null : original.reviewedBy,
      fraudAlertId: isFlagged ? original.id : null,
    );

    await _db.collection('transactions').doc(updated.id).set(updated.toMap());
    await checkBudgetAfterTransaction(
        original.userId, category, transactionDate);
    await logActivity(original.userId,
        'Edited $type of ${amount.toStringAsFixed(0)} FCFA ($category)');
    return updated;
  }

  /// Resolves a Pending Review transaction to 'Approved' or 'Declined' — the
  /// Fraud Review Workflow's Approve/Decline actions. An approval re-runs the
  /// same budget-threshold check every other transaction write does, since an
  /// Approved transaction now counts toward balances/budgets
  /// (`TransactionModel.isCompleted`) exactly like a Completed one.
  Future<void> resolveTransactionReview({
    required TransactionModel tx,
    required String status, // 'Approved' / 'Declined'
    required String reviewedBy,
  }) async {
    final now = DateTime.now().toIso8601String();
    await _db.collection('transactions').doc(tx.id).update({
      'status': status,
      'reviewedAt': now,
      'reviewedBy': reviewedBy,
      'updatedAt': now,
    });
    if (status == 'Approved') {
      await checkBudgetAfterTransaction(tx.userId, tx.category, tx.transactionDate);
    }
  }

  /// Deletes a transaction. For a transfer, both linked legs are removed so the
  /// simulated transfer stays balanced.
  Future<void> deleteTransaction(TransactionModel tx) async {
    var deletedIds = [tx.id];
    if (tx.linkedTransferId != null) {
      final snap = await _db
          .collection('transactions')
          .where('userId', isEqualTo: tx.userId)
          .where('linkedTransferId', isEqualTo: tx.linkedTransferId)
          .get();
      deletedIds = snap.docs.map((d) => d.id).toList();
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } else {
      await _db.collection('transactions').doc(tx.id).delete();
    }
    // A deleted transaction shouldn't leave a fraud alert/notification
    // pointing at a transaction that no longer exists.
    for (final id in deletedIds) {
      await _dismissFraudRecordIfExists(id);
    }
    // Re-run the budget threshold check so a stale 80/90/exceeded alert
    // clears if this deletion brought spend back under it — add/update
    // already do this, delete previously didn't.
    await checkBudgetAfterTransaction(
        tx.userId, tx.category, tx.transactionDate);
    await logActivity(tx.userId,
        'Deleted ${tx.type} of ${tx.amount.toStringAsFixed(0)} FCFA');
  }

  /// Dismisses the `fraud_alerts`/`notifications` docs for a transaction id
  /// if they exist (most transactions have neither — only risky ones do).
  /// Can't hard-delete per the rules' audit-trail design, so this is the
  /// same "dismiss" every other stale-alert cleanup in this app already uses.
  Future<void> _dismissFraudRecordIfExists(String transactionId) async {
    final alertRef = _db.collection('fraud_alerts').doc(transactionId);
    final notificationRef = _db.collection('notifications').doc(transactionId);
    final batch = _db.batch();
    var hasWork = false;
    if ((await alertRef.get()).exists) {
      batch.update(alertRef, {'status': 'dismissed'});
      hasWork = true;
    }
    if ((await notificationRef.get()).exists) {
      batch.update(notificationRef, {'dismissed': true});
      hasWork = true;
    }
    if (hasWork) await batch.commit();
  }

  /// Simulates an internal transfer as two linked records
  /// (transfer-out on source account, transfer-in on destination account).
  Future<void> addTransfer({
    required String userId,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String description,
    required DateTime transactionDate,
    String currency = 'FCFA',
  }) async {
    final linkId = _uuid.v4();
    final now = DateTime.now();

    final outTx = TransactionModel(
      id: _uuid.v4(),
      userId: userId,
      accountId: fromAccountId,
      type: 'Transfer',
      category: 'Transfer Out',
      amount: amount,
      description: description,
      currency: currency,
      transactionDate: transactionDate,
      linkedTransferId: linkId,
      createdAt: now,
      updatedAt: now,
    );

    final inTx = TransactionModel(
      id: _uuid.v4(),
      userId: userId,
      accountId: toAccountId,
      type: 'Transfer',
      category: 'Transfer In',
      amount: amount,
      description: description,
      currency: currency,
      transactionDate: transactionDate,
      linkedTransferId: linkId,
      createdAt: now,
      updatedAt: now,
    );

    final batch = _db.batch();
    batch.set(_db.collection('transactions').doc(outTx.id), outTx.toMap());
    batch.set(_db.collection('transactions').doc(inTx.id), inTx.toMap());
    await batch.commit();
  }

  /// Current balance = opening balance + every completed transaction's
  /// signed contribution (see [TransactionModel.signedAmount]), for one
  /// account. Pending/Failed transactions never affect the balance.
  double calculateAccountBalance(
          AccountModel account, List<TransactionModel> allTx) =>
      account.computeBalance(allTx);

  // ---------------- BUDGETS ----------------
  //
  // Budget persistence itself (create/update/delete/duplicate/reset) lives in
  // `features/budget/data/budget_repository.dart` — the pieces left here are
  // the ones that must run as a side effect of a transaction write,
  // regardless of which screen made it (Transactions, CSV import, etc).

  /// Recomputes spend for every *active* budget in [category] whose date
  /// range covers [date], and fires 80% / 90% / Exceeded alerts. Each
  /// threshold uses a deterministic alert id (`budget_<budgetId>_<key>`), so
  /// re-crossing the same threshold refreshes that one alert instead of
  /// spamming a new one on every subsequent transaction.
  Future<void> checkBudgetAfterTransaction(
      String userId, String category, DateTime date) async {
    final budgetSnap = await _db
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: category)
        .where('status', isEqualTo: 'Active')
        .get();
    if (budgetSnap.docs.isEmpty) return;

    final txSnap = await _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: category)
        .where('type', isEqualTo: 'Expense')
        .get();
    final txs = txSnap.docs
        .map((d) => TransactionModel.fromMap(d.id, d.data()))
        .toList();

    for (final doc in budgetSnap.docs) {
      final budget = BudgetModel.fromMap(doc.id, doc.data());
      if (budget.budgetAmount <= 0) continue;
      if (date.isBefore(budget.startDate) || date.isAfter(budget.endDate)) {
        continue; // this transaction falls outside the budget's own range
      }

      final spent = budget.spentFrom(txs);
      final usagePct = spent / budget.budgetAmount * 100;
      final name = budget.name.isNotEmpty ? budget.name : budget.category;

      if (usagePct >= 100) {
        await setBudgetAlert(
          userId: userId,
          budgetId: budget.id,
          thresholdKey: 'exceeded',
          message:
              'Budget exceeded for $name (${usagePct.toStringAsFixed(0)}% used).',
        );
      } else {
        await _clearBudgetAlertIfStale(budget.id, 'exceeded');
        if (usagePct >= 90) {
          await setBudgetAlert(
            userId: userId,
            budgetId: budget.id,
            thresholdKey: '90',
            message: '90% Budget Used: your $name budget has reached '
                '${usagePct.toStringAsFixed(0)}%.',
          );
        } else {
          await _clearBudgetAlertIfStale(budget.id, '90');
          if (usagePct >= 80) {
            await setBudgetAlert(
              userId: userId,
              budgetId: budget.id,
              thresholdKey: '80',
              message: '80% Budget Used: your $name budget has reached '
                  '${usagePct.toStringAsFixed(0)}%.',
            );
          } else {
            await _clearBudgetAlertIfStale(budget.id, '80');
          }
        }
      }
    }
  }

  /// Dismisses a threshold alert that no longer reflects reality — e.g. the
  /// transaction that pushed a budget to 90% was later edited down or
  /// deleted. Without this, alerts only ever get created, never resolved,
  /// even after the underlying overspend is gone.
  Future<void> _clearBudgetAlertIfStale(
      String budgetId, String thresholdKey) async {
    final ref =
        _db.collection('alerts').doc('budget_${budgetId}_$thresholdKey');
    final snap = await ref.get();
    if (snap.exists && snap.data()?['status'] != 'dismissed') {
      await ref.update({'status': 'dismissed'});
    }
  }

  /// Time-based budget alerts (Ending Soon / Monthly Budget Completed)
  /// aren't triggered by a transaction write, so they're checked whenever
  /// the Budget screen loads instead — see [BudgetAlertsController].
  Future<void> checkBudgetTimeBasedAlerts(String userId) async {
    final now = DateTime.now();
    final budgetSnap = await _db
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'Active')
        .get();

    for (final doc in budgetSnap.docs) {
      final budget = BudgetModel.fromMap(doc.id, doc.data());
      final name = budget.name.isNotEmpty ? budget.name : budget.category;

      if (now.isAfter(budget.endDate)) {
        await setBudgetAlert(
          userId: userId,
          budgetId: budget.id,
          thresholdKey: 'completed',
          message:
              'Monthly Budget Completed: your $name budget period has ended.',
        );
      } else if (budget.endDate.difference(now).inDays <= 2) {
        await setBudgetAlert(
          userId: userId,
          budgetId: budget.id,
          thresholdKey: 'ending_soon',
          message: 'Budget Ending Soon: your $name budget ends in '
              '${budget.endDate.difference(now).inDays} day(s).',
        );
      }
    }
  }

  /// Writes/refreshes a deduplicated budget alert under a deterministic id
  /// (`budget_<budgetId>_<thresholdKey>`) — see [checkBudgetAfterTransaction].
  Future<void> setBudgetAlert({
    required String userId,
    required String budgetId,
    required String thresholdKey,
    required String message,
  }) {
    return _db
        .collection('alerts')
        .doc('budget_${budgetId}_$thresholdKey')
        .set({
      'userId': userId,
      'transactionId': null,
      'alertType': 'budget',
      'message': message,
      'status': 'unread',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  // ---------------- ALERTS ----------------

  Stream<List<Map<String, dynamic>>> streamAlertsRaw(String userId) {
    return _db
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> addAlert({
    required String userId,
    String? transactionId,
    required String alertType,
    required String message,
  }) {
    final id = _uuid.v4();
    return _db.collection('alerts').doc(id).set({
      'userId': userId,
      'transactionId': transactionId,
      'alertType': alertType,
      'message': message,
      'status': 'unread',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> markAlertRead(String id) {
    return _db.collection('alerts').doc(id).update({'status': 'read'});
  }

  /// "Delete" from the Notifications feed's point of view — Firestore rules
  /// deliberately disallow a true delete on this collection so the audit
  /// trail is preserved; dismissing just hides it from the default view.
  Future<void> dismissAlert(String id) {
    return _db.collection('alerts').doc(id).update({'status': 'dismissed'});
  }

  /// Marks every currently-unread alert for [userId] as read in one batch.
  /// Reuses the same (userId, createdAt) query [streamAlertsRaw] already
  /// has a composite index for, filtering to unread client-side rather than
  /// adding a second index for (userId, status).
  Future<void> markAllAlertsRead(String userId) async {
    final snap = await _db
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    final unread = snap.docs.where((d) => d.data()['status'] == 'unread');
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final d in unread) {
      batch.update(d.reference, {'status': 'read'});
    }
    await batch.commit();
  }

  // ---------------- ADMIN ----------------

  Stream<List<AppUser>> streamAllUsers() {
    return _db.collection('users').snapshots().map(
        (s) => s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());
  }

  /// The richer user view for the Admin Users Management screen — `AppUser`
  /// (above) lacks `lastLogin`/`profileCompleted`/region/city/etc., which all
  /// already exist on `AuthUser` (the model the auth/routing stack uses).
  Stream<List<AuthUser>> streamAllAuthUsers() {
    return _db.collection('users').snapshots().map(
        (s) => s.docs.map((d) => AuthUser.fromMap(d.id, d.data())).toList());
  }

  /// Suspends/reactivates a customer account. Writes BOTH `isActive` (what
  /// `AuthUser`/`AuthGate`'s suspension check actually reads) and the legacy
  /// `status` string together — writing only one or the other silently
  /// breaks either old `AppUser`-based code or the live routing gate,
  /// because `AuthUser.fromMap` prefers `isActive` when present as a bool
  /// and ignores `status` entirely in that case.
  Future<void> setUserActiveStatus({
    required String userId,
    required bool isActive,
    required String adminId,
  }) async {
    await _db.collection('users').doc(userId).update({
      'isActive': isActive,
      'status': isActive ? 'active' : 'suspended',
    });
    await logAdminAction(
      adminId: adminId,
      action: 'Admin ${isActive ? 'reactivated' : 'suspended'} account',
      targetUserId: userId,
    );
  }

  /// Backward-compatible string-status setter — kept for any existing
  /// caller, now fixed to also flip `isActive` so suspension actually takes
  /// effect at the routing gate (see [setUserActiveStatus] doc above).
  Future<void> setUserStatus(String userId, String status) async {
    await _db.collection('users').doc(userId).update({
      'status': status,
      'isActive': status != 'suspended',
    });
    await logActivity(userId, 'Admin set account status to $status');
  }

  /// All fraud alerts platform-wide, for the Admin Fraud Monitoring Center
  /// (the customer-scoped [FraudDetectionRepository.watchAlerts] filters by
  /// `userId`, which an admin overview must not).
  Stream<List<FraudAlertModel>> streamAllFraudAlerts() {
    return _db
        .collection('fraud_alerts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => FraudAlertModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// All notifications platform-wide — used by the Admin Analytics screen to
  /// compute [NotificationStats] directly from the live per-recipient docs
  /// (filtered client-side to `adminNotificationId.isNotEmpty`) rather than
  /// a denormalized counter that would need customer clients to write back
  /// to an admin-owned document.
  Stream<List<NotificationModel>> streamAllNotifications() {
    return _db
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => NotificationModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// The admin's own triage state on a fraud alert — independent of the
  /// account owner's Approve/Decline review (see [FraudAlertModel] doc).
  Future<void> updateFraudAlertAdminReview({
    required String alertId,
    required String adminReviewStatus,
    required String adminId,
    String note = '',
  }) async {
    await _db.collection('fraud_alerts').doc(alertId).update({
      'adminReviewStatus': adminReviewStatus,
      'adminReviewNote': note,
      'adminReviewedBy': adminId,
      'adminReviewedAt': DateTime.now().toIso8601String(),
    });
    await logAdminAction(
      adminId: adminId,
      action: 'Fraud review updated to $adminReviewStatus',
      targetUserId: null,
    );
  }

  // ---------------- ADMIN NOTIFICATIONS / ANNOUNCEMENTS ----------------

  Stream<List<AdminNotificationModel>> streamAdminNotifications() {
    return _db
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => AdminNotificationModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Sends an admin-authored broadcast: one `admin_notifications` send-record
  /// (for the admin's own analytics/audit trail) plus one fan-out doc per
  /// recipient into the SAME `notifications` collection the customer app
  /// already streams — no parallel customer-facing inbox is introduced.
  /// [targetUserIds] is ignored when [targetType] is `all` (every non-admin
  /// user in [allUserIds] is targeted instead).
  Future<AdminNotificationModel> sendAdminNotification({
    required AdminNotificationCategory category,
    required String title,
    required String body,
    String priority = 'normal',
    required AdminNotificationTarget targetType,
    List<String> targetUserIds = const [],
    required List<String> allUserIds,
    required String adminId,
  }) async {
    final recipients = targetType == AdminNotificationTarget.all
        ? allUserIds
        : targetUserIds;

    final sendRef = _db.collection('admin_notifications').doc();
    final now = DateTime.now();
    final record = AdminNotificationModel(
      id: sendRef.id,
      category: category,
      title: title,
      body: body,
      priority: priority,
      targetType: targetType,
      targetUserIds: targetType == AdminNotificationTarget.all
          ? const []
          : targetUserIds,
      sentBy: adminId,
      createdAt: now,
      recipientCount: recipients.length,
    );

    // Firestore caps a single batch at 500 writes. Chunk recipients into
    // batches of 400 (leaving headroom for the send-record write, included
    // in the first chunk) so a broadcast to a large user base doesn't
    // silently throw once the platform grows past a few hundred customers.
    const chunkSize = 400;
    final chunks = <List<String>>[];
    for (var start = 0; start < recipients.length; start += chunkSize) {
      chunks.add(recipients.sublist(
          start, (start + chunkSize).clamp(0, recipients.length)));
    }
    if (chunks.isEmpty) chunks.add(const []); // still write the send-record

    for (var i = 0; i < chunks.length; i++) {
      final batch = _db.batch();
      if (i == 0) batch.set(sendRef, record.toMap());
      for (final uid in chunks[i]) {
        final notifRef = _db.collection('notifications').doc();
        batch.set(
            notifRef,
            NotificationModel(
              id: notifRef.id,
              userId: uid,
              title: title,
              body: body,
              type: category.key,
              createdAt: now,
              actionRequired: true,
              actionType: 'support_response',
              adminNotificationId: sendRef.id,
              priority: priority,
            ).toMap());
      }
      await batch.commit();
    }
    await logAdminAction(
      adminId: adminId,
      action: 'Sent ${category.label} to ${recipients.length} customer(s)',
      targetUserId: null,
    );
    return record;
  }

  // ---------------- SUPPORT RESPONSES ----------------

  /// Customer-side: records a quick reaction or short text reply to a
  /// notification, and mirrors its status onto that notification doc so the
  /// admin's Communications screen and the customer's own inbox agree.
  // ---------------- USER PROFILE ----------------

  /// Live stream of a single user's profile (reflects KYC/status changes).
  Stream<AppUser?> streamUser(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((d) => d.exists ? AppUser.fromMap(d.id, d.data()!) : null);
  }

  // ---------------- KYC ----------------

  /// Updates the user's profile photo URL (Cloudinary).
  Future<void> updateUserPhoto(String userId, String url) async {
    await _db.collection('users').doc(userId).update({'photoUrl': url});
    await logActivity(userId, 'Updated profile photo');
  }

  /// Submits a KYC document for review and moves the user to 'pending'.
  Future<void> submitKyc({
    required String userId,
    required String userName,
    required String documentType,
    required String documentReference,
    String documentUrl = '',
  }) async {
    final kyc = KycModel(
      id: _uuid.v4(),
      userId: userId,
      userName: userName,
      documentType: documentType,
      documentReference: documentReference,
      documentUrl: documentUrl,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    await _db.collection('kyc_documents').doc(kyc.id).set(kyc.toMap());
    await _db.collection('users').doc(userId).update({'kycStatus': 'pending'});
    await logActivity(userId, 'Submitted KYC ($documentType)');
  }

  /// Latest KYC submission for a user (sorted client-side to avoid a
  /// composite index on userId + createdAt).
  Stream<KycModel?> streamLatestKyc(String userId) {
    return _db
        .collection('kyc_documents')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) {
      if (s.docs.isEmpty) return null;
      final list = s.docs.map((d) => KycModel.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.first;
    });
  }

  /// All KYC submissions for the admin review queue (pending first).
  Stream<List<KycModel>> streamAllKyc() {
    return _db.collection('kyc_documents').snapshots().map((s) {
      final list = s.docs.map((d) => KycModel.fromMap(d.id, d.data())).toList();
      list.sort((a, b) {
        if (a.status == 'pending' && b.status != 'pending') return -1;
        if (a.status != 'pending' && b.status == 'pending') return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  /// Admin approves/rejects a KYC document and syncs the user's kycStatus.
  Future<void> reviewKyc({
    required String docId,
    required String userId,
    required String status, // 'approved', 'rejected', or 'resubmission_requested'
    required String reviewedBy,
    String reviewNotes = '',
  }) async {
    await _db.collection('kyc_documents').doc(docId).update({
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewedAt': DateTime.now().toIso8601String(),
      'reviewNotes': reviewNotes,
    });
    // A resubmission request isn't a final verdict — the user goes back to
    // 'pending' (they still need to re-upload) rather than 'rejected'.
    await _db.collection('users').doc(userId).update({
      'kycStatus': status == 'resubmission_requested' ? 'pending' : status,
    });
    await logAdminAction(
      adminId: reviewedBy,
      action: 'Reviewed KYC: $status',
      targetUserId: userId,
    );
  }

  // ---------------- ACTIVITY LOGS ----------------

  /// All activity logs for the admin audit view (newest first).
  Stream<List<Map<String, dynamic>>> streamActivityLogs() {
    return _db.collection('activity_logs').snapshots().map((s) {
      final list = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      list.sort((a, b) => (b['createdAt'] ?? '')
          .toString()
          .compareTo((a['createdAt'] ?? '').toString()));
      return list;
    });
  }

  /// All transactions system-wide, for admin reporting (admin-only via rules).
  Stream<List<TransactionModel>> streamAllTransactions() {
    return _db.collection('transactions').snapshots().map((s) =>
        s.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<TransactionModel>> streamFlaggedTransactions() {
    return _db
        .collection('transactions')
        .where('riskLevel', whereIn: ['Medium', 'High', 'Critical'])
        .orderBy('transactionDate', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => TransactionModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> logActivity(String userId, String action) {
    final id = _uuid.v4();
    return _db.collection('activity_logs').doc(id).set({
      'userId': userId,
      'action': action,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Richer audit entry for a Fraud Review action (Approve/Decline/Review
  /// Later) — same `activity_logs` collection as [logActivity], with the
  /// extra fields the review workflow's audit trail needs. `ipAddress` isn't
  /// populated: a client-only Flutter app has no server hop to read a public
  /// IP from without adding a third-party network call, so it's simply
  /// omitted rather than faked.
  Future<void> logReviewActivity({
    required String userId,
    required String transactionId,
    required String action,
    String? device,
  }) {
    final id = _uuid.v4();
    return _db.collection('activity_logs').doc(id).set({
      'userId': userId,
      'action': action,
      'transactionId': transactionId,
      'device': device,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Audit-trail entry for a platform-admin action (suspend/reactivate,
  /// fraud review, KYC decision, notification sent, announcement
  /// published). Same `activity_logs` collection/rules as [logActivity] —
  /// `userId` is the ACTING ADMIN (matching how `reviewKyc` already tags its
  /// log entry with the reviewer's uid, not the reviewed user's), with
  /// [targetUserId] recorded separately so the Admin Audit Log screen can
  /// show "who did what to whom" without ambiguity.
  Future<void> logAdminAction({
    required String adminId,
    required String action,
    String? targetUserId,
  }) {
    final id = _uuid.v4();
    return _db.collection('activity_logs').doc(id).set({
      'userId': adminId,
      'action': action,
      'targetUserId': targetUserId,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
