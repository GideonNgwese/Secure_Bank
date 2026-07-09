import '../../../models/account_model.dart';
import '../../../models/transaction_model.dart';

/// A transaction paired with its resolved account (for display — account
/// name, provider — without every widget re-looking it up).
class TransactionWithAccount {
  final TransactionModel transaction;
  final AccountModel? account;
  const TransactionWithAccount(this.transaction, this.account);
}
