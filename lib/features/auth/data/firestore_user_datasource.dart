import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;
import '../domain/auth_user.dart';

/// Owns the `users/{uid}` collection. Creates a profile on first sign-in and
/// keeps `lastLogin` / `emailVerified` fresh on subsequent logins.
class FirestoreUserDataSource {
  final FirebaseFirestore _db;
  FirestoreUserDataSource(this._db);

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  Future<AuthUser?> fetch(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) return null;
    return AuthUser.fromMap(snap.id, snap.data()!);
  }

  /// Live profile stream — used to react the moment Profile Completion (or any
  /// other screen) writes to this user's document, e.g. to flip routing away
  /// from the Profile Completion screen without a manual navigation call.
  Stream<AuthUser?> watch(String uid) => _doc(uid)
      .snapshots()
      .map((snap) => snap.exists ? AuthUser.fromMap(snap.id, snap.data()!) : null);

  /// Creates the profile if missing, otherwise refreshes login-related fields.
  /// Returns the resulting profile.
  Future<AuthUser> upsertOnLogin(
    User user, {
    required String provider,
    String? fullName,
    String? phone,
  }) async {
    final ref = _doc(user.uid);
    final snap = await ref.get();
    final now = DateTime.now();

    if (!snap.exists) {
      final profile = AuthUser(
        uid: user.uid,
        fullName: fullName?.trim().isNotEmpty == true
            ? fullName!.trim()
            : (user.displayName ?? ''),
        email: user.email ?? '',
        phone: phone?.trim() ?? user.phoneNumber ?? '',
        photoUrl: user.photoURL ?? '',
        role: 'customer',
        provider: provider,
        createdAt: now,
        lastLogin: now,
        emailVerified: user.emailVerified,
        isActive: true,
      );
      await ref.set(profile.toMap());
      return profile;
    }

    // The profile already exists, so never block sign-in if this refresh is
    // rejected/transient — it only bumps lastLogin/emailVerified.
    try {
      await ref.update({
        'lastLogin': now.toIso8601String(),
        'emailVerified': user.emailVerified,
        if ((user.photoURL ?? '').isNotEmpty) 'photoUrl': user.photoURL,
      });
    } catch (_) {/* keep the existing profile */}
    return AuthUser.fromMap(snap.id, snap.data()!)
        .copyWith(lastLogin: now, emailVerified: user.emailVerified);
  }
}
