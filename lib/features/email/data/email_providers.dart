import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/notification_preferences_model.dart';
import 'email_repository.dart';
import 'notification_preferences_repository.dart';

final emailRepositoryProvider =
    Provider<EmailRepository>((ref) => EmailRepository());

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>(
        (ref) => NotificationPreferencesRepository());

final notificationPreferencesProvider =
    StreamProvider.family<NotificationPreferencesModel, String>((ref, userId) =>
        ref.watch(notificationPreferencesRepositoryProvider).watch(userId));
