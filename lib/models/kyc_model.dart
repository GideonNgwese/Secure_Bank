class KycModel {
  final String id;
  final String userId;
  final String userName; // denormalized so admin can list without extra reads
  final String documentType; // National ID / Passport / Driver License ...
  final String documentReference; // document number / reference
  final String documentUrl; // Cloudinary URL of the uploaded document image
  final String status; // pending / approved / rejected
  final String reviewedBy; // admin uid, or '' while pending
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String reviewNotes; // admin's notes on the decision, '' if none

  KycModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.documentType,
    required this.documentReference,
    this.documentUrl = '',
    this.status = 'pending',
    this.reviewedBy = '',
    required this.createdAt,
    this.reviewedAt,
    this.reviewNotes = '',
  });

  factory KycModel.fromMap(String id, Map<String, dynamic> map) {
    return KycModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      documentType: map['documentType'] ?? '',
      documentReference: map['documentReference'] ?? '',
      documentUrl: map['documentUrl'] ?? '',
      status: map['status'] ?? 'pending',
      reviewedBy: map['reviewedBy'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      reviewedAt: map['reviewedAt'] != null
          ? DateTime.tryParse(map['reviewedAt'])
          : null,
      reviewNotes: map['reviewNotes'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'documentType': documentType,
      'documentReference': documentReference,
      'documentUrl': documentUrl,
      'status': status,
      'reviewedBy': reviewedBy,
      'createdAt': createdAt.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewNotes': reviewNotes,
    };
  }
}
