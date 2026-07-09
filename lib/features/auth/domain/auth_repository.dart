import 'auth_user.dart';

/// Domain-facing contract for authentication. The presentation layer depends on
/// this interface only — never on Firebase/Google types directly. Implementations
/// translate infrastructure errors into [AppException]s.
abstract interface class AuthRepository {
  /// Emits the current user (lightweight, from the auth session) or null.
  Stream<AuthUser?> authStateChanges();

  /// The currently signed-in user's uid, if any.
  String? get currentUid;

  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  Future<AuthUser> registerWithEmail({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  });

  Future<AuthUser> signInWithGoogle();

  /// Full profile document from Firestore (may be null if not yet created).
  Future<AuthUser?> fetchProfile(String uid);

  /// Live profile document — drives reactive routing (e.g. Profile Completion
  /// gating) that must update the instant Firestore changes, no manual nav.
  Stream<AuthUser?> watchProfile(String uid);

  /// Interim reset (Firebase email). Phase 4 replaces this with the OTP flow.
  Future<void> sendPasswordResetEmail(String email);

  Future<void> sendEmailVerification();

  /// Reloads the auth user and returns whether the email is now verified.
  Future<bool> refreshEmailVerified();

  Future<void> signOut();
}
