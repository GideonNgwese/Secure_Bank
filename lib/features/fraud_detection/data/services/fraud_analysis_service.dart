import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../models/account_model.dart';
import '../../../../models/budget_model.dart';
import '../../../../models/fraud_alert_model.dart';
import '../../../../models/transaction_model.dart';
import '../../domain/fraud_rules.dart';
import '../../domain/fraud_signal.dart';
import '../../domain/risk_level.dart';
import '../fraud_detection_repository.dart';

/// Orchestrates fraud analysis at write time: fetches the user's recent
/// history, runs [FraudRuleEngine], and — if the result is risky — records a
/// [FraudAlertModel]. This is what `FirestoreService.addTransaction` /
/// `updateTransaction` call right after scoring a transaction, exactly where
/// the old `FraudService` used to plug in.
///
/// Deliberately has no dependency on `FirestoreService` (which depends on
/// this class instead) — balance is computed via [AccountModel.computeBalance],
/// a pure model method with no service dependency, so this and
/// `FirestoreService.calculateAccountBalance` share one formula without a
/// circular import.
class FraudAnalysisService {
  final FirebaseFirestore _db;
  final FraudDetectionRepository _repo;

  FraudAnalysisService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance,
        _repo = FraudDetectionRepository(db);

  Future<List<TransactionModel>> _fetchHistory(String userId,
      {String? excludeId}) async {
    final snap = await _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('transactionDate', descending: true)
        .limit(200)
        .get();
    return snap.docs
        .map((d) => TransactionModel.fromMap(d.id, d.data()))
        .where((t) => t.id != excludeId)
        .toList();
  }

  Future<double> _currentBalance(
      String accountId, List<TransactionModel> history) async {
    final snap = await _db.collection('accounts').doc(accountId).get();
    if (!snap.exists) return 0;
    final account = AccountModel.fromMap(snap.id, snap.data()!);
    return account.computeBalance(history);
  }

  Future<List<BudgetModel>> _fetchActiveBudgets(String userId) async {
    final snap = await _db
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'Active')
        .get();
    return snap.docs.map((d) => BudgetModel.fromMap(d.id, d.data())).toList();
  }

  /// Runs the rule engine against [candidate] and records a `fraud_alerts`
  /// document if the result is Medium risk or above. [excludeId] should be
  /// the transaction's own id when re-scoring an edit, so it doesn't count
  /// itself as a duplicate/rapid-fire signal against its own prior version.
  Future<FraudAnalysisResult> analyzeAndRecord({
    required String userId,
    required String transactionId,
    required FraudCandidate candidate,
    String? excludeId,
  }) async {
    final history = await _fetchHistory(userId, excludeId: excludeId);
    final balance = await _currentBalance(candidate.accountId, history);
    final activeBudgets = await _fetchActiveBudgets(userId);
    final result = FraudRuleEngine.analyze(FraudContext(
      candidate: candidate,
      history: history,
      currentAccountBalance: balance,
      activeBudgets: activeBudgets,
    ));

    if (result.isRisky) {
      await _repo.recordAlert(FraudAlertModel(
        id: '',
        userId: userId,
        transactionId: transactionId,
        riskScore: result.score,
        riskLevel: result.level.label,
        reason: result.reason,
        recommendation: result.recommendation,
        createdAt: DateTime.now(),
        // Every alert recorded here is already Medium+ (isRisky excludes
        // Low), so this always ends up true today — kept as its own field
        // rather than hardcoded so a future alert source with different
        // semantics isn't forced to require review too.
        reviewRequired: true,
      ));
    }
    return result;
  }
}
