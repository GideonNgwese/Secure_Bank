/// A transaction's settlement state. Only `completed` transactions count
/// toward calculated balances — mirrors how real banking apps exclude
/// pending/failed activity from the settled balance.
///
/// 'Pending Review', 'Approved' and 'Declined' are system-managed states set
/// by the Fraud Review Workflow (never offered in the manual status picker
/// on the transaction form) — a Medium+ risk transaction is saved as
/// 'Pending Review' instead of 'Completed', then moves to 'Approved' or
/// 'Declined' once the user resolves the flag on the Fraud Review screen.
const kTransactionStatuses = ['Completed', 'Pending', 'Failed'];
const kFraudReviewStatuses = ['Pending Review', 'Approved', 'Declined'];

class TransactionModel {
  final String id;
  final String userId;
  final String accountId;
  final String type; // Income / Expense / Transfer / Refund / Adjustment
  final String category;
  final double amount;
  final String title;
  final String description;
  final String currency; // FCFA default
  final String paymentMethod;
  final String merchant;
  final String location;
  final String receiptUrl; // Cloudinary secure URL, empty if none
  final String status; // Completed / Pending / Failed
  final DateTime transactionDate;
  final int riskScore;
  final String riskLevel; // Low / Medium / High
  final String? linkedTransferId; // for transfer pairs
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt; // when a fraud review action was taken
  final String? reviewedBy; // uid who resolved the review (self-attestation)
  final String? fraudAlertId; // paired fraud_alerts doc id, if flagged

  TransactionModel({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.type,
    required this.category,
    required this.amount,
    this.title = '',
    required this.description,
    this.currency = 'FCFA',
    this.paymentMethod = '',
    this.merchant = '',
    this.location = '',
    this.receiptUrl = '',
    this.status = 'Completed',
    required this.transactionDate,
    this.riskScore = 0,
    this.riskLevel = 'Low',
    this.linkedTransferId,
    required this.createdAt,
    this.updatedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.fraudAlertId,
  });

  // 'Approved' is a resolved fraud review that clears a transaction to
  // process normally — it counts toward balances exactly like 'Completed'.
  bool get isCompleted => status == 'Completed' || status == 'Approved';
  bool get isPendingReview => status == 'Pending Review';

  /// This transaction's signed contribution to its account's balance.
  /// Non-`Completed` transactions (Pending/Failed) never affect balances.
  /// Adjustment amounts carry their own sign (positive = credit correction,
  /// negative = debit correction) since they have no fixed direction.
  double get signedAmount {
    if (!isCompleted) return 0;
    switch (type) {
      case 'Income':
      case 'Refund':
        return amount;
      case 'Expense':
        return -amount;
      case 'Transfer':
        return category == 'Transfer In' ? amount : -amount;
      case 'Adjustment':
        return amount;
      default:
        return 0;
    }
  }

  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) {
    return TransactionModel(
      id: id,
      userId: map['userId'] ?? '',
      accountId: map['accountId'] ?? '',
      type: map['type'] ?? 'Expense',
      category: map['category'] ?? 'Other',
      amount: (map['amount'] ?? 0).toDouble(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      currency: map['currency'] ?? 'FCFA',
      // tolerate legacy docs written with `paymentChannel`
      paymentMethod: map['paymentMethod'] ?? map['paymentChannel'] ?? '',
      merchant: map['merchant'] ?? '',
      location: map['location'] ?? '',
      receiptUrl: map['receiptUrl'] ?? '',
      status: map['status'] ?? 'Completed',
      transactionDate:
          DateTime.tryParse(map['transactionDate'] ?? '') ?? DateTime.now(),
      riskScore: map['riskScore'] ?? 0,
      riskLevel: map['riskLevel'] ?? 'Low',
      linkedTransferId: map['linkedTransferId'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt:
          map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
      reviewedAt: map['reviewedAt'] != null
          ? DateTime.tryParse(map['reviewedAt'])
          : null,
      reviewedBy: map['reviewedBy'],
      fraudAlertId: map['fraudAlertId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'accountId': accountId,
      'type': type,
      'category': category,
      'amount': amount,
      'title': title,
      'description': description,
      'currency': currency,
      'paymentMethod': paymentMethod,
      'merchant': merchant,
      'location': location,
      'receiptUrl': receiptUrl,
      'status': status,
      'transactionDate': transactionDate.toIso8601String(),
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'linkedTransferId': linkedTransferId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'fraudAlertId': fraudAlertId,
    };
  }

  TransactionModel copyWith({
    String? status,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? fraudAlertId,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
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
      status: status ?? this.status,
      transactionDate: transactionDate,
      riskScore: riskScore,
      riskLevel: riskLevel,
      linkedTransferId: linkedTransferId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      fraudAlertId: fraudAlertId ?? this.fraudAlertId,
    );
  }
}
