import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show User;

/// Domain user model backing the `users/{uid}` Firestore document.
class AuthUser {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String photoUrl;
  final String role; // customer | admin
  final String provider; // password | google
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool emailVerified;
  final bool isActive;

  /// Whether the post-signup Profile Completion step has been finished.
  /// Missing on legacy docs (pre-dating this field) is treated as false —
  /// those users are prompted once, same as brand-new signups.
  final bool profileCompleted;
  final String gender;
  final DateTime? dateOfBirth;
  final String region;
  final String city;
  final String occupation;
  final String preferredCurrency;
  final String preferredLanguage;
  // Already a denormalized field on the same `users/{uid}` doc (written by
  // KycRepository.submitKyc / FirestoreService.reviewKyc) — just wasn't
  // exposed on this model until the Admin Users Management screen needed
  // "Verification Status" alongside the rest of a customer's profile.
  final String kycStatus; // not_submitted / pending / approved / rejected

  const AuthUser({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.photoUrl = '',
    this.role = 'customer',
    this.provider = 'password',
    required this.createdAt,
    this.lastLogin,
    this.emailVerified = false,
    this.isActive = true,
    this.profileCompleted = false,
    this.gender = '',
    this.dateOfBirth,
    this.region = '',
    this.city = '',
    this.occupation = '',
    this.preferredCurrency = 'FCFA',
    this.preferredLanguage = 'English',
    this.kycStatus = 'not_submitted',
  });

  bool get isAdmin => role == 'admin';
  bool get isSuspended => !isActive;

  /// Lightweight mapping from a Firebase Auth user (no Firestore read) — used
  /// for the auth-state stream and as a fallback before the profile loads.
  factory AuthUser.fromFirebase(User u, {String provider = 'password'}) {
    return AuthUser(
      uid: u.uid,
      fullName: u.displayName ?? '',
      email: u.email ?? '',
      phone: u.phoneNumber ?? '',
      photoUrl: u.photoURL ?? '',
      provider: provider,
      createdAt: u.metadata.creationTime ?? DateTime.now(),
      lastLogin: u.metadata.lastSignInTime,
      emailVerified: u.emailVerified,
    );
  }

  factory AuthUser.fromMap(String id, Map<String, dynamic> map) {
    return AuthUser(
      uid: id,
      // tolerate legacy docs that used `name` instead of `fullName`
      fullName: (map['fullName'] ?? map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      photoUrl: (map['photoUrl'] ?? '') as String,
      role: (map['role'] ?? 'customer') as String,
      provider: (map['provider'] ?? 'password') as String,
      createdAt: _date(map['createdAt']) ?? DateTime.now(),
      lastLogin: _date(map['lastLogin']),
      emailVerified: (map['emailVerified'] ?? false) as bool,
      // tolerate legacy `status: active|suspended`
      isActive: map['isActive'] is bool
          ? map['isActive'] as bool
          : (map['status'] ?? 'active') != 'suspended',
      profileCompleted: (map['profileCompleted'] ?? false) as bool,
      gender: (map['gender'] ?? '') as String,
      dateOfBirth: _date(map['dateOfBirth']),
      region: (map['region'] ?? '') as String,
      city: (map['city'] ?? '') as String,
      occupation: (map['occupation'] ?? '') as String,
      preferredCurrency: (map['preferredCurrency'] ?? 'FCFA') as String,
      preferredLanguage: (map['preferredLanguage'] ?? 'English') as String,
      kycStatus: (map['kycStatus'] ?? 'not_submitted') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'fullName': fullName,
        // legacy `name` + `status` kept for existing screens AND the deployed
        // security rules, which require `status == 'active'` on user creation.
        'name': fullName,
        'status': isActive ? 'active' : 'suspended',
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        'role': role,
        'provider': provider,
        'createdAt': createdAt.toIso8601String(),
        'lastLogin': lastLogin?.toIso8601String(),
        'emailVerified': emailVerified,
        'isActive': isActive,
        'profileCompleted': profileCompleted,
        'gender': gender,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'region': region,
        'city': city,
        'occupation': occupation,
        'preferredCurrency': preferredCurrency,
        'preferredLanguage': preferredLanguage,
        'kycStatus': kycStatus,
      };

  AuthUser copyWith({
    String? fullName,
    String? phone,
    String? photoUrl,
    String? role,
    DateTime? lastLogin,
    bool? emailVerified,
    bool? isActive,
    bool? profileCompleted,
    String? gender,
    DateTime? dateOfBirth,
    String? region,
    String? city,
    String? occupation,
    String? preferredCurrency,
    String? preferredLanguage,
    String? kycStatus,
  }) =>
      AuthUser(
        uid: uid,
        fullName: fullName ?? this.fullName,
        email: email,
        phone: phone ?? this.phone,
        photoUrl: photoUrl ?? this.photoUrl,
        role: role ?? this.role,
        provider: provider,
        createdAt: createdAt,
        lastLogin: lastLogin ?? this.lastLogin,
        emailVerified: emailVerified ?? this.emailVerified,
        isActive: isActive ?? this.isActive,
        profileCompleted: profileCompleted ?? this.profileCompleted,
        gender: gender ?? this.gender,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        region: region ?? this.region,
        city: city ?? this.city,
        occupation: occupation ?? this.occupation,
        preferredCurrency: preferredCurrency ?? this.preferredCurrency,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        kycStatus: kycStatus ?? this.kycStatus,
      );

  static DateTime? _date(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    if (v is DateTime) return v;
    return null;
  }
}
