/// The background picker's tabs, in display order. A value the app doesn't
/// know yet (one the backend added later) is [other], so it never vanishes.
enum BackgroundCategory {
  indoor('indoor'),
  urban('urban'),
  nature('nature'),
  other('');

  final String apiValue;
  const BackgroundCategory(this.apiValue);

  /// Missing → [indoor] (a backend from before categories); unknown → [other].
  static BackgroundCategory fromApiValue(String? value) {
    if (value == null || value.isEmpty) return indoor;
    for (final c in values) {
      if (c != other && c.apiValue == value) return c;
    }
    return other;
  }
}

/// A try-on background from `GET /backgrounds`. Its [id] is the
/// `background_id` sent to generate; ids differ between environments, so
/// never hard-code one.
class BackgroundOption {
  final int id;

  /// A stable code (`tokyo_street_1`), not a display name.
  final String name;

  /// The display name, in the account's backend `locale`; null from a
  /// backend that predates it.
  final String? label;
  final BackgroundCategory category;

  /// Signed preview URL; null when the background has no image yet.
  final String? imageUrl;
  final String? imageCacheKey;

  const BackgroundOption({
    required this.id,
    required this.name,
    this.label,
    this.category = BackgroundCategory.indoor,
    this.imageUrl,
    this.imageCacheKey,
  });

  /// The backend's Default Fitting Room, which always exists.
  static const int defaultId = 0;

  factory BackgroundOption.fromJson(Map<String, dynamic> json) {
    return BackgroundOption(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      label: json['label'] as String?,
      category: BackgroundCategory.fromApiValue(json['category'] as String?),
      imageUrl: json['image_url'] as String?,
      imageCacheKey: json['image_cache_key'] as String?,
    );
  }

  /// [name] as words (`tokyo_street` → `Tokyo Street`), for a background the
  /// app has no translated label for yet.
  String get fallbackLabel => name
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// The background an outfit starts on: Default Fitting Room, else the first
/// listed. Looked up by id — the backend may reorder the list.
BackgroundOption? defaultBackground(List<BackgroundOption> backgrounds) {
  for (final b in backgrounds) {
    if (b.id == BackgroundOption.defaultId) return b;
  }
  return backgrounds.isEmpty ? null : backgrounds.first;
}
