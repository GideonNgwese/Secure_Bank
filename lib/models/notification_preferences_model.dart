/// Per-user notification preferences. Firestore collection:
/// `notification_preferences`, doc id == uid.
///
/// [emailEnabled] is a master switch for the OPTIONAL/informational email
/// categories below it — it does NOT suppress security-critical email
/// (account created, password changed, fraud alerts, account suspended/
/// reactivated, new-device sign-in, OTP). Those are never user-disable-able,
/// the same way a real bank never lets you turn off fraud/security
/// notifications — see `EmailRepository` for the enforcement point.
class NotificationPreferencesModel {
  final bool emailEnabled;
  final bool pushEnabled; // stored for forward-compat; no push (FCM) integration yet
  final bool inAppEnabled;
  final bool transactionReceipts;
  final bool budgetReminders;
  final bool monthlySummary;
  final bool adminAnnouncements;
  final bool kycUpdates;
  final DateTime? updatedAt;

  const NotificationPreferencesModel({
    this.emailEnabled = true,
    this.pushEnabled = true,
    this.inAppEnabled = true,
    this.transactionReceipts = true,
    this.budgetReminders = true,
    this.monthlySummary = true,
    this.adminAnnouncements = true,
    this.kycUpdates = true,
    this.updatedAt,
  });

  factory NotificationPreferencesModel.fromMap(Map<String, dynamic> map) {
    return NotificationPreferencesModel(
      emailEnabled: map['emailEnabled'] ?? true,
      pushEnabled: map['pushEnabled'] ?? true,
      inAppEnabled: map['inAppEnabled'] ?? true,
      transactionReceipts: map['transactionReceipts'] ?? true,
      budgetReminders: map['budgetReminders'] ?? true,
      monthlySummary: map['monthlySummary'] ?? true,
      adminAnnouncements: map['adminAnnouncements'] ?? true,
      kycUpdates: map['kycUpdates'] ?? true,
      updatedAt:
          map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'emailEnabled': emailEnabled,
      'pushEnabled': pushEnabled,
      'inAppEnabled': inAppEnabled,
      'transactionReceipts': transactionReceipts,
      'budgetReminders': budgetReminders,
      'monthlySummary': monthlySummary,
      'adminAnnouncements': adminAnnouncements,
      'kycUpdates': kycUpdates,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  NotificationPreferencesModel copyWith({
    bool? emailEnabled,
    bool? pushEnabled,
    bool? inAppEnabled,
    bool? transactionReceipts,
    bool? budgetReminders,
    bool? monthlySummary,
    bool? adminAnnouncements,
    bool? kycUpdates,
  }) {
    return NotificationPreferencesModel(
      emailEnabled: emailEnabled ?? this.emailEnabled,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      inAppEnabled: inAppEnabled ?? this.inAppEnabled,
      transactionReceipts: transactionReceipts ?? this.transactionReceipts,
      budgetReminders: budgetReminders ?? this.budgetReminders,
      monthlySummary: monthlySummary ?? this.monthlySummary,
      adminAnnouncements: adminAnnouncements ?? this.adminAnnouncements,
      kycUpdates: kycUpdates ?? this.kycUpdates,
      updatedAt: DateTime.now(),
    );
  }
}
