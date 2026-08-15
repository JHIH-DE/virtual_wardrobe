import 'package:flutter/material.dart';

/// Stable "learned preference" dimension identifiers. New dimensions can be
/// added here without touching any Style Taste UI — pages render whatever
/// list of dimensions the backend (currently: the mock
/// `StyleTasteService`) returns, data-driven.
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

/// Glyph shown next to this dimension's axis on [StyleTasteRadarChart] and
/// in its "Key Insights" row — same icon in both spots so the two are
/// visually tied together.
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

/// One learned preference bar — LUMI's current read on where the user sits
/// between a dimension's two poles (e.g. Style Balance's Consistent/Mixed).
/// Purely a visualization of what's been learned; never user-editable.
class StyleTastePreference {
  final StyleTasteDimension dimension;

  /// 0.0 = the dimension's low pole, 1.0 = the high pole.
  final double score;

  /// 0.0-1.0, how confident LUMI is in [score]. Not surfaced in the UI yet —
  /// carried through so a future version can show it (e.g. fade bars with
  /// low confidence) without a model change.
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
