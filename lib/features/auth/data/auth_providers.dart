import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_repository_impl.dart';
import 'firebase_auth_datasource.dart';
import 'firestore_user_datasource.dart';
import 'services/otp_api_service.dart';

/// Infrastructure singletons.
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Datasources.
final authDataSourceProvider = Provider<FirebaseAuthDataSource>(
    (ref) => FirebaseAuthDataSource(ref.watch(firebaseAuthProvider)));
final userDataSourceProvider = Provider<FirestoreUserDataSource>(
    (ref) => FirestoreUserDataSource(ref.watch(firestoreProvider)));

/// Repository.
final authRepositoryProvider = Provider<AuthRepository>((ref) =>
    AuthRepositoryImpl(
        ref.watch(authDataSourceProvider), ref.watch(userDataSourceProvider)));

/// Backend OTP/Brevo email service.
final otpApiServiceProvider = Provider<OtpApiService>((ref) => OtpApiService());

/// Reactive auth session (null when signed out). Drives routing.
final authStateChangesProvider = StreamProvider<AuthUser?>(
    (ref) => ref.watch(authRepositoryProvider).authStateChanges());

/// Full Firestore profile for the signed-in user (null if none/loading).
final currentProfileProvider = FutureProvider<AuthUser?>((ref) async {
  final auth = ref.watch(authStateChangesProvider).valueOrNull;
  if (auth == null) return null;
  return ref.watch(authRepositoryProvider).fetchProfile(auth.uid);
});

/// Live Firestore profile for the signed-in user — reacts instantly to writes
/// (e.g. Profile Completion flipping `profileCompleted` to true), which is
/// what [AuthGate] watches to decide Profile Completion vs Dashboard.
final currentProfileStreamProvider = StreamProvider<AuthUser?>((ref) {
  final auth = ref.watch(authStateChangesProvider).valueOrNull;
  if (auth == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchProfile(auth.uid);
});
