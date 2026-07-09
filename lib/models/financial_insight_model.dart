/// An automatically-generated financial insight (spending trend, savings
/// change, income diversity, category overspend, etc). Firestore collection:
/// `financial_insights`. Uses deterministic IDs per (userId, type, period) so
/// regenerating a month's insights refreshes them in place instead of
/// duplicating — see `SmartInsightsEngine`.
class FinancialInsightModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final String sentiment; // positive / neutral / warning
  final String period; // e.g. '2026-07', for dedup/regeneration
  final String status; // unread / read / dismissed
  final DateTime createdAt;

  const FinancialInsightModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.sentiment = 'neutral',
    required this.period,
    this.status = 'unread',
    required this.createdAt,
  });

  bool get isUnread => status == 'unread';

  factory FinancialInsightModel.fromMap(String id, Map<String, dynamic> map) {
    return FinancialInsightModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      sentiment: map['sentiment'] ?? 'neutral',
      period: map['period'] ?? '',
      status: map['status'] ?? 'unread',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'sentiment': sentiment,
      'period': period,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
