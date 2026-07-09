/// One message inside a [NotificationThreadModel] conversation. Firestore
/// collection: `thread_messages`. Not a general chat message — every one of
/// these is tied to exactly one thread, which is itself tied to exactly one
/// notification (see that model's doc).
class ThreadMessageModel {
  final String id;
  final String threadId;
  final String senderId;
  final String senderRole; // 'customer' | 'admin'
  final String receiverId;
  final String message;
  final String? responseType; // quick-reaction key, null for free-text
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool read;
  final DateTime? readAt;

  const ThreadMessageModel({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderRole,
    required this.receiverId,
    required this.message,
    this.responseType,
    required this.createdAt,
    this.updatedAt,
    this.read = false,
    this.readAt,
  });

  bool get isFromAdmin => senderRole == 'admin';
  bool get isFromCustomer => senderRole == 'customer';

  factory ThreadMessageModel.fromMap(String id, Map<String, dynamic> map) {
    return ThreadMessageModel(
      id: id,
      threadId: map['threadId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderRole: map['senderRole'] ?? 'customer',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      responseType: map['responseType'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt:
          map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
      read: map['read'] ?? false,
      readAt: map['readAt'] != null ? DateTime.tryParse(map['readAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'threadId': threadId,
      'senderId': senderId,
      'senderRole': senderRole,
      'receiverId': receiverId,
      'message': message,
      'responseType': responseType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'read': read,
      'readAt': readAt?.toIso8601String(),
    };
  }
}
