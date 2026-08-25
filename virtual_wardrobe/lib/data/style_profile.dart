import 'style_type.dart';

/// One entry from `GET /users/me/style_profile` (`ProfileService
/// .getMyStyleProfile`) — how many of the user's outfits are tagged with
/// [style]. The backend already sorts these high to low by [count]. [style]
/// is null when the backend returns a style string this app doesn't
/// recognize yet — [rawStyle] is kept so callers can still show *something*
/// rather than silently dropping the entry.
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
