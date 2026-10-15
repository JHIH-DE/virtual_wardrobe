import 'style_type.dart';

/// How many of the user's outfits are tagged with [style]; the backend sorts
/// by [count], high to low. [style] is null for an unrecognized value —
/// [rawStyle] keeps it showable.
class StyleProfileItem {
  final StyleType? style;
  final String rawStyle;
  final int count;

  const StyleProfileItem({
    required this.style,
    required this.rawStyle,
    required this.count,
  });

  factory StyleProfileItem.fromJson(Map<String, dynamic> json) {
    final raw = json['style'] as String? ?? '';
    return StyleProfileItem(
      style: styleTypeFromApiValue(raw),
      rawStyle: raw,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
