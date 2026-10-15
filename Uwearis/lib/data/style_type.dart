/// Season catalog shared by the outfit filters and the Edit Tags sheet.
const List<String> seasonOptions = ['Spring', 'Summer', 'Autumn', 'Winter'];

/// Style catalog shared by the outfit filters and the Edit Tags sheet.
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

/// Only these (never a localized label) go over the API.
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

/// snake_case wire format (e.g. `smart_casual`).
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
