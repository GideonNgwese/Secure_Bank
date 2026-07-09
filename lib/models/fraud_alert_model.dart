/// A rule-engine-generated fraud/risk alert tied to one transaction.
/// Firestore collection: `fraud_alerts`.
class FraudAlertModel {
  final String id;
  final String userId;
  final String transactionId;
  final int riskScore; // 0-100
  final String riskLevel; // Low / Medium / High / Critical
  final String reason; // human-readable explanation of what triggered it
  final String recommendation; // what the user should consider doing
  final String status; // unread / read / dismissed / approved / confirmed_fraud
  final DateTime createdAt;
  // Fraud Review Workflow fields — additive, backward compatible with alerts
  // written before this feature (all default to "not yet reviewed").
  final bool reviewRequired; // true when level is Medium+ (mirrors isRisky)
  final DateTime? resolvedAt; // when Approve/Decline was actioned
  final String? resolution; // 'approved' / 'confirmed_fraud', null until resolved
  // Admin Fraud Monitoring Center — a SEPARATE triage track from the fields
  // above. `status`/`resolution` belong to the account owner's own
  // Approve/Decline review (see FraudReviewController); these fields are the
  // platform admin's independent investigation state, so the two workflows
  // can never stomp on each other's values.
  final String adminReviewStatus; // '' / under_review / resolved / false_positive / escalated
  final String adminReviewNote;
  final String? adminReviewedBy;
  final DateTime? adminReviewedAt;

  const FraudAlertModel({
    required this.id,
    required this.userId,
    required this.transactionId,
    required this.riskScore,
    required this.riskLevel,
    required this.reason,
    required this.recommendation,
    this.status = 'unread',
    required this.createdAt,
    this.reviewRequired = false,
    this.resolvedAt,
    this.resolution,
    this.adminReviewStatus = '',
    this.adminReviewNote = '',
    this.adminReviewedBy,
    this.adminReviewedAt,
  });

  bool get isUnread => status == 'unread';
  bool get isResolved => resolution != null && resolution!.isNotEmpty;

  factory FraudAlertModel.fromMap(String id, Map<String, dynamic> map) {
    return FraudAlertModel(
      id: id,
      userId: map['userId'] ?? '',
      transactionId: map['transactionId'] ?? '',
      riskScore: (map['riskScore'] ?? 0) is int
          ? map['riskScore'] ?? 0
          : (map['riskScore'] as num).toInt(),
      riskLevel: map['riskLevel'] ?? 'Low',
      reason: map['reason'] ?? '',
      recommendation: map['recommendation'] ?? '',
      status: map['status'] ?? 'unread',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      reviewRequired: map['reviewRequired'] ?? false,
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'])
          : null,
      resolution: map['resolution'],
      adminReviewStatus: map['adminReviewStatus'] ?? '',
      adminReviewNote: map['adminReviewNote'] ?? '',
      adminReviewedBy: map['adminReviewedBy'],
      adminReviewedAt: map['adminReviewedAt'] != null
          ? DateTime.tryParse(map['adminReviewedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'transactionId': transactionId,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'reason': reason,
      'recommendation': recommendation,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'reviewRequired': reviewRequired,
      'resolvedAt': resolvedAt?.toIso8601String(),
      'resolution': resolution,
      'adminReviewStatus': adminReviewStatus,
      'adminReviewNote': adminReviewNote,
      'adminReviewedBy': adminReviewedBy,
      'adminReviewedAt': adminReviewedAt?.toIso8601String(),
    };
  }
}
