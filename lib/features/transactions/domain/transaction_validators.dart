/// Pure, reusable validators for the Add/Edit Transaction form.
class TransactionValidators {
  TransactionValidators._();

  /// Income/Expense/Transfer/Refund amounts must be a positive magnitude.
  /// Adjustment amounts carry their own sign (see [TransactionModel.
  /// signedAmount]) and just need to be non-zero.
  static String? amount(String? v, {required bool allowNegative}) {
    final n = double.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a valid amount';
    if (allowNegative) {
      if (n == 0) return 'Amount cannot be zero';
    } else if (n <= 0) {
      return 'Amount must be greater than 0';
    }
    return null;
  }

  static String? required(String? v, String label) =>
      (v ?? '').trim().isEmpty ? '$label is required' : null;
}
