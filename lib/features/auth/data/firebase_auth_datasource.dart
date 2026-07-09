import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper over FirebaseAuth + Google Sign-In. Knows nothing about
/// Firestore or domain models — it only deals in Firebase [User]s.
class FirebaseAuthDataSource {
  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  FirebaseAuthDataSource(this._auth, {GoogleSignIn? googleSignIn})
      : _google = googleSignIn ?? GoogleSignIn();

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    return cred.user!;
  }

  Future<User> register(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    return cred.user!;
  }

  Future<void> updateDisplayName(String name) async =>
      _auth.currentUser?.updateDisplayName(name);

  /// Runs the Google flow and signs into Firebase. Throws a
  /// FirebaseAuthException(code: 'cancelled') if the user backs out.
  Future<User> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) {
      throw FirebaseAuthException(
          code: 'cancelled', message: 'Google sign-in was cancelled');
    }
    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    return cred.user!;
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> refreshEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {/* not signed in with Google */}
    await _auth.signOut();
  }
}
