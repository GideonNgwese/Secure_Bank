import '../../../models/kyc_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';

/// Owns the Profile & KYC screen's Firestore access — profile photo,
/// live user profile, and identity-document submission/status — so that
/// screen no longer instantiates `FirestoreService()` directly.
class KycRepository {
  final FirestoreService _fs;
  KycRepository([FirestoreService? fs]) : _fs = fs ?? FirestoreService();

  Stream<AppUser?> watchUser(String userId) => _fs.streamUser(userId);

  Stream<KycModel?> watchLatestKyc(String userId) =>
      _fs.streamLatestKyc(userId);

  Future<void> updatePhoto(String userId, String url) =>
      _fs.updateUserPhoto(userId, url);

  Future<void> submitKyc({
    required String userId,
    required String userName,
    required String documentType,
    required String documentReference,
    String documentUrl = '',
  }) =>
      _fs.submitKyc(
        userId: userId,
        userName: userName,
        documentType: documentType,
        documentReference: documentReference,
        documentUrl: documentUrl,
      );
}
