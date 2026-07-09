import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'firebase_auth_datasource.dart';
import 'firestore_user_datasource.dart';

/// Orchestrates the auth + user datasources and translates every infrastructure
/// error into a friendly [AppException] via [mapError].
class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDataSource _auth;
  final FirestoreUserDataSource _users;

  AuthRepositoryImpl(this._auth, this._users);

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(
      (user) => user == null ? null : AuthUser.fromFirebase(user));

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _auth.signIn(email.trim(), password);
      return await _users.upsertOnLogin(user, provider: 'password');
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final user = await _auth.register(email.trim(), password);
      await _auth.updateDisplayName(fullName.trim());
      // When the backend is configured, email verification is done via Brevo
      // OTP (from the Verify-Email screen), not Firebase's spam-prone link.
      if (!AppConfig.hasApi) {
        await _auth.sendEmailVerification();
      }
      return await _users.upsertOnLogin(
        user,
        provider: 'password',
        fullName: fullName,
        phone: phone,
      );
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      final user = await _auth.signInWithGoogle();
      return await _users.upsertOnLogin(user, provider: 'google');
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<AuthUser?> fetchProfile(String uid) async {
    try {
      return await _users.fetch(uid);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Stream<AuthUser?> watchProfile(String uid) => _users.watch(uid);

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email.trim());
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      await _auth.sendEmailVerification();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<bool> refreshEmailVerified() async {
    try {
      return await _auth.refreshEmailVerified();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw mapError(e);
    }
  }
}
