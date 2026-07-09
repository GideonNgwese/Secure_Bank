import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

/// Handles registration, login, logout and current-user profile lookup.
/// Role is stored in Firestore (users/{uid}.role) -- 'customer' or 'admin'.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final appUser = AppUser(
      id: cred.user!.uid,
      name: name,
      email: email,
      phone: phone,
      role: 'customer',
      createdAt: DateTime.now(),
    );

    await _db.collection('users').doc(appUser.id).set(appUser.toMap());
    await _log(appUser.id, 'Registered new account');
    return appUser;
  }

  Future<UserCredential> login(String email, String password) async {
    final cred =
        await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (cred.user != null) await _log(cred.user!.uid, 'Logged in');
    return cred;
  }

  /// Writes an activity-log entry (best-effort; never blocks auth on failure).
  Future<void> _log(String uid, String action) async {
    try {
      await _db.collection('activity_logs').add({
        'userId': uid,
        'action': action,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {/* logging must not break login/registration */}
  }

  /// Signs in with Google, creating the Firestore profile on first sign-in.
  /// Requires the Google provider to be enabled in the Firebase Console and the
  /// app's SHA-1 fingerprint registered (otherwise this throws).
  Future<AppUser> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
          code: 'cancelled', message: 'Google sign-in was cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    final user = cred.user!;

    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      final appUser = AppUser(
        id: user.uid,
        name: user.displayName ?? 'User',
        email: user.email ?? '',
        phone: user.phoneNumber ?? '',
        role: 'customer',
        createdAt: DateTime.now(),
      );
      await docRef.set(appUser.toMap());
      await _log(user.uid, 'Registered via Google');
      return appUser;
    }
    await _log(user.uid, 'Logged in with Google');
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  Future<void> logout() async {
    // Also disconnect Google so the account chooser appears next time.
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  Future<void> resetPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }
}
