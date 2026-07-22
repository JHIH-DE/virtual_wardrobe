/// Stable style identifiers. These are the only values that should be
/// persisted in the database or sent/received via the API — never a
/// localized display label.
enum StyleType {
  minimalist,
  korean,
  streetwear,
  smartCasual,
  chic,
  athleisure,
  oldMoney,
  romantic,
  vintage,
  bohemian,
  cityBoy,
  americanCasual,
  workwear,
  gorpcore,
  techwear,
  outdoor,
}

/// Wire-format (de)serialization. Kept backward-compatible with the
/// display-case strings ("City Boy", "Old Money", ...) already stored by
/// the backend and in existing `Look`/profile data, so no API or data
/// migration is required to introduce this enum.
extension StyleTypeApi on StyleType {
  String get apiValue {
    switch (this) {
      case StyleType.minimalist:
        return 'Minimalist';
      case StyleType.korean:
        return 'Korean';
      case StyleType.streetwear:
        return 'Streetwear';
      case StyleType.smartCasual:
        return 'Smart Casual';
      case StyleType.chic:
        return 'Chic';
      case StyleType.athleisure:
        return 'Athleisure';
      case StyleType.oldMoney:
        return 'Old Money';
      case StyleType.romantic:
        return 'Romantic';
      case StyleType.vintage:
        return 'Vintage';
      case StyleType.bohemian:
        return 'Bohemian';
      case StyleType.cityBoy:
        return 'City Boy';
      case StyleType.americanCasual:
        return 'American Casual';
      case StyleType.workwear:
        return 'Workwear';
      case StyleType.gorpcore:
        return 'Gorpcore';
      case StyleType.techwear:
        return 'Techwear';
      case StyleType.outdoor:
        return 'Outdoor';
    }
  }
}

StyleType? styleTypeFromApiValue(String value) {
  for (final style in StyleType.values) {
    if (style.apiValue == value) return style;
  }
  return null;
}
