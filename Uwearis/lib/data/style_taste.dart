import 'package:flutter/material.dart';

/// The UI renders whichever of these the API returned.
enum StyleTasteDimension {
  styleBalance,
  colorPairing,
  fitPreference,
  layering,
  accessories,
}

extension StyleTasteDimensionApi on StyleTasteDimension {
  String get apiValue => switch (this) {
    StyleTasteDimension.styleBalance => 'style_balance',
    StyleTasteDimension.colorPairing => 'color_pairing',
    StyleTasteDimension.fitPreference => 'fit_preference',
    StyleTasteDimension.layering => 'layering',
    StyleTasteDimension.accessories => 'accessories',
  };
}

/// Shared by the radar chart axis and the "Key Insights" row.
extension StyleTasteDimensionIcon on StyleTasteDimension {
  IconData get icon => switch (this) {
    StyleTasteDimension.styleBalance => Icons.join_inner,
    StyleTasteDimension.colorPairing => Icons.palette_outlined,
    StyleTasteDimension.fitPreference => Icons.checkroom_outlined,
    StyleTasteDimension.layering => Icons.layers_outlined,
    StyleTasteDimension.accessories => Icons.watch_outlined,
  };
}

StyleTasteDimension? styleTasteDimensionFromApiValue(String value) {
  for (final dimension in StyleTasteDimension.values) {
    if (dimension.apiValue == value) return dimension;
  }
  return null;
}

/// Where the user sits between a dimension's two poles. Read-only.
class StyleTastePreference {
  final StyleTasteDimension dimension;

  /// 0.0 = the dimension's low pole, 1.0 = the high pole.
  final double score;

  /// 0.0-1.0. Not shown in the UI yet.
  final double confidence;

  final String? description;

  const StyleTastePreference({
    required this.dimension,
    required this.score,
    this.confidence = 1.0,
    this.description,
  });

  factory StyleTastePreference.fromJson(Map<String, dynamic> json) {
    return StyleTastePreference(
      dimension:
          styleTasteDimensionFromApiValue(json['dimension'] as String? ?? '') ??
          StyleTasteDimension.styleBalance,
      score: (json['score'] as num?)?.toDouble() ?? 0.5,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'dimension': dimension.apiValue,
    'score': score,
    'confidence': confidence,
    'description': description,
  };

  StyleTastePreference copyWith({
    double? score,
    double? confidence,
    String? description,
  }) {
    return StyleTastePreference(
      dimension: dimension,
      score: score ?? this.score,
      confidence: confidence ?? this.confidence,
      description: description ?? this.description,
    );
  }
}

/// `GET /users/me/style_taste`: the [summary] paragraph plus the radar
/// chart's [preferences].
class StyleTasteProfile {
  final String status;
  final String summary;
  final List<StyleTastePreference> preferences;

  const StyleTasteProfile({
    required this.status,
    required this.summary,
    required this.preferences,
  });

  /// The API keys each dimension by `apiValue` (unlike
  /// [StyleTastePreference.fromJson]'s flat list). Missing dimensions are
  /// skipped: a `"learning"` response may omit some.
  factory StyleTasteProfile.fromApi(Map<String, dynamic> data) {
    final preferences = <StyleTastePreference>[];
    for (final dimension in StyleTasteDimension.values) {
      final raw = data[dimension.apiValue];
      if (raw is! Map<String, dynamic>) continue;
      preferences.add(
        StyleTastePreference(
          dimension: dimension,
          score: (raw['score'] as num?)?.toDouble() ?? 0.5,
          confidence: (raw['confidence'] as num?)?.toDouble() ?? 0.0,
          description: raw['insight'] as String?,
        ),
      );
    }
    return StyleTasteProfile(
      status: data['status'] as String? ?? 'learning',
      summary: data['summary'] as String? ?? '',
      preferences: preferences,
    );
  }
}
