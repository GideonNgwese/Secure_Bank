/// Curated option lists for the Profile Completion form. Kept as simple
/// constants (mirrors the pattern already used for account providers/types)
/// so new options can be added without touching any widget code.
class ProfileFields {
  ProfileFields._();

  static const List<String> genders = [
    'Male',
    'Female',
    'Prefer not to say',
  ];

  /// Cameroon's 10 administrative regions.
  static const List<String> regions = [
    'Adamawa',
    'Centre',
    'East',
    'Far North',
    'Littoral',
    'North',
    'Northwest',
    'South',
    'Southwest',
    'West',
  ];

  static const List<String> occupations = [
    'Employed',
    'Self-employed',
    'Business owner',
    'Civil servant',
    'Student',
    'Farmer',
    'Unemployed',
    'Retired',
    'Other',
  ];

  static const List<String> currencies = ['FCFA', 'USD', 'EUR', 'GBP'];

  static const List<String> languages = ['English', 'French'];
}
