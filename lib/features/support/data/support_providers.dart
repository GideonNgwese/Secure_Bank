import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/notification_thread_model.dart';
import '../../../models/thread_message_model.dart';
import 'support_repository.dart';

final supportRepositoryProvider =
    Provider<SupportRepository>((ref) => SupportRepository());

final myThreadsProvider =
    StreamProvider.family<List<NotificationThreadModel>, String>((ref, userId) =>
        ref.watch(supportRepositoryProvider).watchMyThreads(userId));

/// All threads platform-wide, for the Admin Response Center.
final allThreadsProvider = StreamProvider<List<NotificationThreadModel>>(
    (ref) => ref.watch(supportRepositoryProvider).watchAllThreads());

final threadProvider = StreamProvider.family<NotificationThreadModel?, String>(
    (ref, threadId) =>
        ref.watch(supportRepositoryProvider).watchThread(threadId));

final threadMessagesProvider =
    StreamProvider.family<List<ThreadMessageModel>, String>((ref, threadId) =>
        ref.watch(supportRepositoryProvider).watchMessages(threadId));

/// Count of threads with an unread-by-admin message — the admin nav badge.
final unreadThreadCountProvider = Provider<int>((ref) {
  final threads = ref.watch(allThreadsProvider).valueOrNull ?? [];
  return threads.where((t) => t.adminUnread).length;
});

/// Count of threads with an unread-by-customer message — the customer
/// notifications bell badge can fold this in alongside the existing
/// unread-notification count.
final myUnreadThreadCountProvider = Provider.family<int, String>((ref, userId) {
  final threads = ref.watch(myThreadsProvider(userId)).valueOrNull ?? [];
  return threads.where((t) => t.customerUnread).length;
});
