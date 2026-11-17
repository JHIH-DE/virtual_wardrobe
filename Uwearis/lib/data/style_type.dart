/// Season catalog shared by the outfit filters and the Edit Tags sheet, in
/// the backend's form. Display through `outfitTagLabel`.
const List<String> seasonOptions = ['spring', 'summer', 'autumn', 'winter'];

/// Style catalog shared by the outfit filters and the Edit Tags sheet, in
/// the backend's snake_case form. Display through `outfitTagLabel`.
final List<String> styleOptions = [
  for (final s in StyleType.values) s.apiValue,
];

/// An outfit's season/style tag in the catalog's form, ignoring case and
/// separators (`Smart Casual` / `STREET_WEAR` → `smart_casual` /
/// `streetwear`). A tag outside the catalog is only lower/snake-cased.
String normalizeOutfitTag(String tag) {
  final value = tag.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), '_');
  final key = value.replaceAll('_', '');
  for (final v in [...seasonOptions, ...styleOptions]) {
    if (v.replaceAll('_', '') == key) return v;
  }
  return value;
}

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
