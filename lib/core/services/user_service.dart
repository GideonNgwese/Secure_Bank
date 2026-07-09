import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

/// Thin façade the header (and any other core widget) uses to reach the
/// current user's profile without depending on a feature-specific provider
/// file. Wraps the same [FirestoreService]/[AuthService] every feature
/// already talks to — no parallel data path.
class UserService {
  final FirestoreService _firestore;
  final AuthService _auth;

  UserService({FirestoreService? firestore, AuthService? auth})
      : _firestore = firestore ?? FirestoreService(),
        _auth = auth ?? AuthService();

  String? get currentUserId => _auth.currentUser?.uid;

  Stream<AppUser?> streamProfile(String userId) =>
      _firestore.streamUser(userId);
}
