import 'garment.dart';

/// One choice from `GET /garments/sub-categories`: [value] is what
/// `sub_category` (L2) or, for one of [styles], `style` (L3) stores and
/// PATCH sends; [label] is in the user's locale.
class SubCategoryOption {
  final String value;
  final String label;

  /// The L3 styles under this L2; empty when it has none (Jeans, Scarves).
  final List<SubCategoryOption> styles;

  const SubCategoryOption({
    required this.value,
    required this.label,
    this.styles = const [],
  });
}

/// The backend's fixed sub-category lists, in display order, per category.
class SubCategoryCatalog {
  final Map<GarmentCategory, List<SubCategoryOption>> byCategory;
  final Map<String, String> _labels;

  /// A value shared by two categories ("Shirt" in Top and Outer)
  /// has one label.
  SubCategoryCatalog(this.byCategory)
    : _labels = {
        for (final options in byCategory.values)
          for (final o in options) ...{
            o.value: o.label,
            for (final style in o.styles) style.value: style.label,
          },
      };

  List<SubCategoryOption> optionsFor(GarmentCategory category) =>
      byCategory[category] ?? const [];

  bool allows(GarmentCategory category, String value) =>
      optionsFor(category).any((o) => o.value == value);

  /// The L3 styles under [subCategory] in [category]'s list.
  List<SubCategoryOption> stylesFor(
    GarmentCategory category,
    String subCategory,
  ) {
    for (final o in optionsFor(category)) {
      if (o.value == subCategory) return o.styles;
    }
    return const [];
  }

  /// [value]'s label (an L2 or L3 value); the value itself when no list has it (rows from
  /// before the lists existed, or a stale catalog).
  String labelFor(String value) => _labels[value] ?? value;

  factory SubCategoryCatalog.fromJson(List<dynamic> data) {
    final byCategory = <GarmentCategory, List<SubCategoryOption>>{};
    for (final entry in data) {
      if (entry is! Map<String, dynamic>) continue;
      final category = entry['category'];
      final options = entry['options'];
      if (category is! String || options is! List) continue;
      // fromApiValue falls back to Top; a category this build doesn't know
      // must not overwrite Top's list.
      final known = GarmentCategory.values.where(
        (c) => c.apiValue.toLowerCase() == category.toLowerCase(),
      );
      if (known.isEmpty) continue;
      byCategory[known.first] = [
        for (final o in options)
          if (_parseOption(o) case final option?)
            SubCategoryOption(
              value: option.value,
              label: option.label,
              styles: switch (o['styles']) {
                final List<dynamic> styles => [
                  for (final style in styles) ?_parseOption(style),
                ],
                _ => const [],
              },
            ),
      ];
    }
    return SubCategoryCatalog(byCategory);
  }

  static SubCategoryOption? _parseOption(dynamic o) {
    if (o is! Map<String, dynamic> || o['value'] is! String) return null;
    final value = o['value'] as String;
    // One odd label must not fail the whole list.
    final label = o['label'];
    return SubCategoryOption(
      value: value,
      label: label is String ? label : value,
    );
  }
}
