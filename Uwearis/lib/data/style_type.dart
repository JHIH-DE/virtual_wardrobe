/// Season filter/tag catalog shared by outfits_page.dart,
/// garment_outfits_page.dart (as filter options, with an extra leading
/// 'All' sentinel), and outfit_details_page.dart (as the Edit Tags sheet's
/// catalog) — kept as one list so the three stay in sync.
const List<String> seasonOptions = ['Spring', 'Summer', 'Autumn', 'Winter'];

/// Style filter/tag catalog shared by outfits_page.dart,
/// garment_outfits_page.dart (as filter options, with an extra leading
/// 'All' sentinel), and outfit_details_page.dart (as the Edit Tags sheet's
/// catalog) — kept as one list so the three stay in sync.
const List<String> styleOptions = [
  'Minimal',
  'Classic',
  'Smart Casual',
  'Streetwear',
  'Athleisure',
  'Workwear',
  'Preppy',
  'Business',
  'Vintage',
];

/// Stable style identifiers. These are the only values that should be
/// persisted in the database or sent/received via the API — never a
/// localized display label.
enum StyleType {
  minimal,
  classic,
  smartCasual,
  streetwear,
  athleisure,
  workwear,
  preppy,
  business,
  vintage,
}

/// Wire-format (de)serialization — the backend's outfit-style category
/// list, snake_case (e.g. `smart_casual`).
extension StyleTypeApi on StyleType {
  String get apiValue {
    switch (this) {
      case StyleType.minimal:
        return 'minimal';
      case StyleType.classic:
        return 'classic';
      case StyleType.smartCasual:
        return 'smart_casual';
      case StyleType.streetwear:
        return 'streetwear';
      case StyleType.athleisure:
        return 'athleisure';
      case StyleType.workwear:
        return 'workwear';
      case StyleType.preppy:
        return 'preppy';
      case StyleType.business:
        return 'business';
      case StyleType.vintage:
        return 'vintage';
    }
  }
}

StyleType? styleTypeFromApiValue(String value) {
  for (final style in StyleType.values) {
    if (style.apiValue == value) return style;
  }
  return null;
}
