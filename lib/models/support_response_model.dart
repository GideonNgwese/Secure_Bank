/// A customer's response to a notification — either one of five fixed quick-
/// reactions, or a short free-text reply capped at [kSupportResponseMaxChars].
/// Persisted as a `ThreadMessageModel.responseType` inside the lightweight
/// conversation model (see `notification_thread_model.dart`), not as its own
/// collection — this file now only owns the response-type vocabulary shared
/// by the customer Reply Composer and the Admin Response Center.
enum SupportResponseType { acknowledge, confirm, thankYou, needHelp, contactSupport, text }

extension SupportResponseTypeX on SupportResponseType {
  String get key => switch (this) {
        SupportResponseType.acknowledge => 'acknowledge',
        SupportResponseType.confirm => 'confirm',
        SupportResponseType.thankYou => 'thank_you',
        SupportResponseType.needHelp => 'need_help',
        SupportResponseType.contactSupport => 'contact_support',
        SupportResponseType.text => 'text',
      };

  String get label => switch (this) {
        SupportResponseType.acknowledge => 'Acknowledge',
        SupportResponseType.confirm => 'Confirm',
        SupportResponseType.thankYou => 'Thank You',
        SupportResponseType.needHelp => 'Need Help',
        SupportResponseType.contactSupport => 'Contact Support',
        SupportResponseType.text => 'Message',
      };

  String get emoji => switch (this) {
        SupportResponseType.acknowledge => '👍',
        SupportResponseType.confirm => '✅',
        SupportResponseType.thankYou => '🙏',
        SupportResponseType.needHelp => '⚠',
        SupportResponseType.contactSupport => '❓',
        SupportResponseType.text => '💬',
      };

  static SupportResponseType fromKey(String key) => switch (key) {
        'confirm' => SupportResponseType.confirm,
        'thank_you' => SupportResponseType.thankYou,
        'need_help' => SupportResponseType.needHelp,
        'contact_support' => SupportResponseType.contactSupport,
        'text' => SupportResponseType.text,
        _ => SupportResponseType.acknowledge,
      };
}

const kSupportResponseMaxChars = 250;
