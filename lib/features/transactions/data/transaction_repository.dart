import '../../../models/transaction_model.dart';
import '../../../services/firestore_service.dart';

/// Owns transaction persistence. Wraps the shared [FirestoreService] (fraud
/// scoring, budget alerts, transfer pairing, activity log all live there and
/// are reused, not duplicated) while giving this feature a clean, typed,
/// widget-free surface. Accounts + balance calc are intentionally NOT
/// duplicated here — the transactions feature reuses `features/accounts`'
/// providers/repository directly, the single owner of that logic.
class TransactionRepository {
  final FirestoreService _fs;
  TransactionRepository(this._fs);

  /// Live transactions for a user, most recent first, capped at [limit] for
  /// an efficient bounded query. The list screen grows [limit] on "load
  /// more" rather than paging with cursors, so this stays a single simple
  /// live stream (real-time updates keep working at every page size).
  Stream<List<TransactionModel>> watch(String userId, {int limit = 60}) =>
      _fs.streamTransactionsLimited(userId, limit: limit);

  /// Live single transaction by id, for the Fraud Review Screen.
  Stream<TransactionModel?> watchById(String id) =>
      _fs.streamTransactionById(id);

  Future<TransactionModel> create({
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
  }) =>
      _fs.addTransaction(
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
        status: status,
        transactionDate: transactionDate,
        simulateNewDevice: simulateNewDevice,
      );

  Future<TransactionModel> update({
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
  }) =>
      _fs.updateTransaction(
        original: original,
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
        status: status,
        transactionDate: transactionDate,
        simulateNewDevice: simulateNewDevice,
      );

  Future<void> createTransfer({
    required String userId,
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required String description,
    required DateTime transactionDate,
    String currency = 'FCFA',
  }) =>
      _fs.addTransfer(
        userId: userId,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: amount,
        description: description,
        transactionDate: transactionDate,
        currency: currency,
      );

  Future<void> delete(TransactionModel tx) => _fs.deleteTransaction(tx);

  /// Fraud Review Workflow: resolves a Pending Review transaction to
  /// Approved/Declined. See [FirestoreService.resolveTransactionReview].
  Future<void> resolveReview({
    required TransactionModel tx,
    required String status,
    required String reviewedBy,
  }) =>
      _fs.resolveTransactionReview(tx: tx, status: status, reviewedBy: reviewedBy);

  /// One-shot fetch of every transaction (used by CSV import for
  /// duplicate detection against the full history, not just the bounded
  /// [watch] page).
  Future<List<TransactionModel>> fetchAll(String userId) =>
      _fs.getTransactions(userId);

  Future<void> logActivity(String userId, String action) =>
      _fs.logActivity(userId, action);
}
