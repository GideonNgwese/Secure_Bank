import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/notification_preferences_model.dart';

/// Owns the `notification_preferences` collection — the Settings screen's
/// Email Preferences section reads/writes through this.
class NotificationPreferencesRepository {
  final FirebaseFirestore _db;
  NotificationPreferencesRepository([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;

  Stream<NotificationPreferencesModel> watch(String userId) {
    return _db
        .collection('notification_preferences')
        .doc(userId)
        .snapshots()
        .map((d) => d.exists
            ? NotificationPreferencesModel.fromMap(d.data()!)
            : const NotificationPreferencesModel());
  }

  Future<void> update(String userId, NotificationPreferencesModel prefs) {
    return _db
        .collection('notification_preferences')
        .doc(userId)
        .set(prefs.toMap(), SetOptions(merge: true));
  }
}
