import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/notification_thread_model.dart';
import '../../../models/thread_message_model.dart';
import '../../../services/firestore_service.dart';

/// Owns the `notification_threads` + `thread_messages` collections — the
/// lightweight, bounded conversation model (max [kMaxThreadMessages]
/// messages) that replaced the old one-shot `support_responses` collection.
/// One thread per notification (deterministic doc id = notificationId).
class SupportRepository {
  final FirebaseFirestore _db;
  SupportRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  // ---------------- Threads ----------------

  Stream<List<NotificationThreadModel>> watchMyThreads(String userId) {
    return _db
        .collection('notification_threads')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => NotificationThreadModel.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt)));
  }

  /// All threads platform-wide, for the Admin Response Center.
  Stream<List<NotificationThreadModel>> watchAllThreads() {
    return _db.collection('notification_threads').snapshots().map((s) {
      final list = s.docs
          .map((d) => NotificationThreadModel.fromMap(d.id, d.data()))
          .toList();
      list.sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.lastMessageAt.compareTo(a.lastMessageAt);
      });
      return list;
    });
  }

  Stream<NotificationThreadModel?> watchThread(String threadId) {
    return _db
        .collection('notification_threads')
        .doc(threadId)
        .snapshots()
        .map((d) =>
            d.exists ? NotificationThreadModel.fromMap(d.id, d.data()!) : null);
  }

  // ---------------- Messages ----------------

  Stream<List<ThreadMessageModel>> watchMessages(String threadId) {
    return _db
        .collection('thread_messages')
        .where('threadId', isEqualTo: threadId)
        .orderBy('createdAt')
        .snapshots()
        .map((s) => s.docs
            .map((d) => ThreadMessageModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Adds a message to a thread, creating the thread first if this is the
  /// first reply to that notification. Runs as a transaction so the
  /// [kMaxThreadMessages] cap can't be raced past by two near-simultaneous
  /// sends, and so `messageCount`/`lastMessage*` on the thread never drift
  /// out of sync with the messages actually written.
  Future<void> sendMessage({
    required String notificationId,
    required String userId,
    String userName = '',
    String userEmail = '',
    required String title,
    ThreadCategory category = ThreadCategory.general,
    String priority = 'normal',
    required String senderId,
    required String senderRole, // 'customer' | 'admin'
    required String receiverId,
    required String message,
    String? responseType,
  }) async {
    final threadRef =
        _db.collection('notification_threads').doc(notificationId);
    final messageRef = _db.collection('thread_messages').doc();
    final now = DateTime.now();
    final preview =
        message.length > 80 ? '${message.substring(0, 80)}…' : message;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(threadRef);
      final currentCount =
          snap.exists ? ((snap.data()?['messageCount'] ?? 0) as int) : 0;
      if (currentCount >= kMaxThreadMessages) {
        throw StateError(
            'This conversation has reached its $kMaxThreadMessages-reply limit.');
      }

      final notifyAdmin = senderRole == 'customer';

      if (!snap.exists) {
        tx.set(
            threadRef,
            NotificationThreadModel(
              id: notificationId,
              notificationId: notificationId,
              userId: userId,
              userName: userName,
              userEmail: userEmail,
              title: title,
              category: category,
              priority: priority,
              messageCount: 1,
              lastMessageAt: now,
              lastMessagePreview: preview,
              lastSenderRole: senderRole,
              adminUnread: notifyAdmin,
              customerUnread: !notifyAdmin,
              createdAt: now,
              updatedAt: now,
            ).toMap());
      } else {
        final update = <String, dynamic>{
          'messageCount': currentCount + 1,
          'lastMessageAt': now.toIso8601String(),
          'lastMessagePreview': preview,
          'lastSenderRole': senderRole,
          'updatedAt': now.toIso8601String(),
          if (notifyAdmin) 'adminUnread': true else 'customerUnread': true,
        };
        // A new customer message reopens a resolved/closed thread. Admin
        // replies don't auto-change status — resolving/closing is always an
        // explicit admin action (see updateStatus).
        if (senderRole == 'customer') {
          update['status'] = ThreadStatus.open.key;
        }
        tx.update(threadRef, update);
      }

      tx.set(
          messageRef,
          ThreadMessageModel(
            id: messageRef.id,
            threadId: notificationId,
            senderId: senderId,
            senderRole: senderRole,
            receiverId: receiverId,
            message: message,
            responseType: responseType,
            createdAt: now,
          ).toMap());
    });
  }

  /// Marks every message NOT sent by [readerRole] as read, and clears that
  /// party's unread flag on the thread — called when that party opens the
  /// thread. The thread-level flag is cleared unconditionally (not just when
  /// unread messages were found) since it's the authoritative badge signal.
  Future<void> markRead(
      {required String threadId, required String readerRole}) async {
    final otherRole = readerRole == 'admin' ? 'customer' : 'admin';
    final snap = await _db
        .collection('thread_messages')
        .where('threadId', isEqualTo: threadId)
        .where('senderRole', isEqualTo: otherRole)
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    final now = DateTime.now().toIso8601String();
    for (final d in snap.docs) {
      batch.update(d.reference, {'read': true, 'readAt': now});
    }
    batch.update(_db.collection('notification_threads').doc(threadId), {
      readerRole == 'admin' ? 'adminUnread' : 'customerUnread': false,
    });
    await batch.commit();
  }

  /// Admin-only status transition (Mark Resolved / Request More Information
  /// -> pending / Close Conversation).
  Future<void> updateStatus({
    required String threadId,
    required ThreadStatus status,
    required String adminId,
    String? targetUserId,
  }) async {
    await _db.collection('notification_threads').doc(threadId).update({
      'status': status.key,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await FirestoreService().logAdminAction(
      adminId: adminId,
      action: 'Conversation marked ${status.label}',
      targetUserId: targetUserId,
    );
  }

  Future<void> setPinned(
      {required String threadId, required bool pinned}) async {
    await _db.collection('notification_threads').doc(threadId).update({
      'pinned': pinned,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
