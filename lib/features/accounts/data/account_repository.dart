import '../../../models/account_model.dart';
import '../../../models/transaction_model.dart';
import '../../../services/firestore_service.dart';

/// Owns account persistence + balance calculation. Wraps the shared
/// [FirestoreService] so the rest of the app keeps working, while giving the
/// accounts feature a clean, testable surface (no Firestore in widgets).
class AccountRepository {
  final FirestoreService _fs;
  AccountRepository(this._fs);

  Stream<List<AccountModel>> watchAccounts(String userId) =>
      _fs.streamAccounts(userId);

  Stream<List<TransactionModel>> watchTransactions(String userId) =>
      _fs.streamTransactions(userId);

  double balanceOf(AccountModel account, List<TransactionModel> txs) =>
      _fs.calculateAccountBalance(account, txs);

  Future<void> create(AccountModel account) =>
      _fs.addAccount(account.copyWith(updatedAt: DateTime.now()));

  Future<void> update(AccountModel account) =>
      _fs.updateAccount(account.copyWith(updatedAt: DateTime.now()));

  Future<void> setStatus(AccountModel account, String status) =>
      _fs.updateAccount(
          account.copyWith(status: status, updatedAt: DateTime.now()));

  Future<void> delete(String id) => _fs.deleteAccount(id);
}
