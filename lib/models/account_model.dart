import 'transaction_model.dart';

class AccountModel {
  final String id;
  final String userId;
  final String accountName;
  final String provider;
  final String accountType; // Bank / Mobile Money / Cash / Savings / Business
  final String maskedNumber;
  final double openingBalance;
  final String currency; // FCFA default
  final String status; // Active / Inactive / Archived
  final DateTime createdAt;
  final DateTime? updatedAt;

  AccountModel({
    required this.id,
    required this.userId,
    required this.accountName,
    required this.provider,
    required this.accountType,
    required this.maskedNumber,
    required this.openingBalance,
    this.currency = 'FCFA',
    this.status = 'Active',
    required this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'Active';
  bool get isArchived => status == 'Archived';

  /// Opening balance + the signed sum of every completed transaction on this
  /// account — the single formula [FirestoreService.calculateAccountBalance]
  /// and [FraudAnalysisService] both use, so a fix here fixes it everywhere
  /// instead of the two independently drifting. Lives on the model (not a
  /// service) so both call sites can depend on it without a circular import
  /// through `FirestoreService`.
  double computeBalance(List<TransactionModel> allTx) {
    var balance = openingBalance;
    for (final t in allTx) {
      if (t.accountId == id) balance += t.signedAmount;
    }
    return balance;
  }

  factory AccountModel.fromMap(String id, Map<String, dynamic> map) {
    return AccountModel(
      id: id,
      userId: map['userId'] ?? '',
      accountName: map['accountName'] ?? '',
      provider: map['provider'] ?? '',
      accountType: map['accountType'] ?? '',
      maskedNumber: map['maskedNumber'] ?? '',
      openingBalance: (map['openingBalance'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'FCFA',
      status: map['status'] ?? 'Active',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt:
          map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'accountName': accountName,
      'provider': provider,
      'accountType': accountType,
      'maskedNumber': maskedNumber,
      'openingBalance': openingBalance,
      'currency': currency,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  AccountModel copyWith({
    String? accountName,
    String? provider,
    String? accountType,
    String? maskedNumber,
    double? openingBalance,
    String? currency,
    String? status,
    DateTime? updatedAt,
  }) =>
      AccountModel(
        id: id,
        userId: userId,
        accountName: accountName ?? this.accountName,
        provider: provider ?? this.provider,
        accountType: accountType ?? this.accountType,
        maskedNumber: maskedNumber ?? this.maskedNumber,
        openingBalance: openingBalance ?? this.openingBalance,
        currency: currency ?? this.currency,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
