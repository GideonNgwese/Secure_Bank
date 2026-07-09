class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String photoUrl; // Cloudinary URL, empty if none
  final String role; // 'customer' or 'admin'
  final String status; // 'active' or 'suspended'
  final String kycStatus; // 'not_submitted', 'pending', 'approved', 'rejected'
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.photoUrl = '',
    this.role = 'customer',
    this.status = 'active',
    this.kycStatus = 'not_submitted',
    required this.createdAt,
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      // new auth schema uses `fullName`; fall back for forward-compatibility
      name: (map['name'] ?? map['fullName'] ?? '') as String,
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      role: map['role'] ?? 'customer',
      // new schema uses `isActive` (bool); legacy used `status`
      status: map['status'] ??
          ((map['isActive'] == false) ? 'suspended' : 'active'),
      kycStatus: map['kycStatus'] ?? 'not_submitted',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'role': role,
      'status': status,
      'kycStatus': kycStatus,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
