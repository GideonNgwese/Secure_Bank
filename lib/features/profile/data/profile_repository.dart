import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/profile_draft.dart';

/// Owns the write side of profile completion. Reads reuse the existing
/// `users/{uid}` stream from the auth feature — this repository only ever
/// updates fields, never re-creates the document (that happens at sign-up).
class ProfileRepository {
  final FirebaseFirestore _db;
  ProfileRepository(this._db);

  Future<void> completeProfile(String uid, ProfileDraft draft) {
    return _db.collection('users').doc(uid).update({
      'fullName': draft.fullName,
      'name': draft.fullName, // kept in sync for legacy AppUser readers
      'phone': draft.phone,
      'gender': draft.gender,
      'dateOfBirth': draft.dateOfBirth?.toIso8601String(),
      'region': draft.region,
      'city': draft.city,
      'occupation': draft.occupation,
      'preferredCurrency': draft.preferredCurrency,
      'preferredLanguage': draft.preferredLanguage,
      if (draft.photoUrl.isNotEmpty) 'photoUrl': draft.photoUrl,
      'profileCompleted': true,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}
