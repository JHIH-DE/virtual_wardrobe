import 'garment.dart';

/// The five bands the backend derives deterministically from the 1–10
/// `level`.
enum VersatilityLabel {
  veryLimited,
  limited,
  moderate,
  versatile,
  highlyVersatile,
}

extension VersatilityLabelX on VersatilityLabel {
  String get apiValue {
    switch (this) {
      case VersatilityLabel.veryLimited:
        return 'Very Limited';
      case VersatilityLabel.limited:
        return 'Limited';
      case VersatilityLabel.moderate:
        return 'Moderate';
      case VersatilityLabel.versatile:
        return 'Versatile';
      case VersatilityLabel.highlyVersatile:
        return 'Highly Versatile';
    }
  }

  static VersatilityLabel fromApiValue(String? value) {
    final lower = value?.trim().toLowerCase();
    return VersatilityLabel.values.firstWhere(
      (e) => e.apiValue.toLowerCase() == lower,
      orElse: () => VersatilityLabel.moderate,
    );
  }
}

class ClosetAnalysisVersatility {
  final int level;
  final VersatilityLabel label;

  const ClosetAnalysisVersatility({required this.level, required this.label});

  factory ClosetAnalysisVersatility.fromJson(Map<String, dynamic> json) {
    return ClosetAnalysisVersatility(
      level: (json['level'] as num?)?.toInt() ?? 1,
      label: VersatilityLabelX.fromApiValue(json['label'] as String?),
    );
  }

  /// API shape, so `GarmentService`'s persisted cache round-trips.
  Map<String, dynamic> toJson() => {'level': level, 'label': label.apiValue};
}

/// Lightweight garment projection embedded in the response (not a full
/// [Garment]). [isTarget] marks the analyzed garment in an outfit idea.
class ClosetAnalysisGarment {
  final int garmentId;
  final GarmentCategory category;
  final String? name;
  final String imageUrl;
  final bool isTarget;

  const ClosetAnalysisGarment({
    required this.garmentId,
    required this.category,
    required this.imageUrl,
    this.name,
    this.isTarget = false,
  });

  factory ClosetAnalysisGarment.fromJson(Map<String, dynamic> json) {
    return ClosetAnalysisGarment(
      garmentId: (json['garment_id'] as num?)?.toInt() ?? 0,
      category: GarmentCategoryX.fromApiValue(json['category'] as String?),
      name: json['name'] as String?,
      imageUrl: (json['image_url'] as String?) ?? '',
      isTarget: (json['is_target'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'garment_id': garmentId,
    'category': category.apiValue,
    'name': name,
    'image_url': imageUrl,
    'is_target': isTarget,
  };
}

/// A suggested outfit around the analyzed garment. Display-only — never
/// creates an `Outfit` or a try-on render.
class ClosetAnalysisOutfitIdea {
  final String title;
  final List<ClosetAnalysisGarment> garments;

  const ClosetAnalysisOutfitIdea({required this.title, required this.garments});

  factory ClosetAnalysisOutfitIdea.fromJson(Map<String, dynamic> json) {
    return ClosetAnalysisOutfitIdea(
      title: (json['title'] as String?) ?? '',
      garments:
          (json['garments'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ClosetAnalysisGarment.fromJson)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'garments': garments.map((g) => g.toJson()).toList(),
  };
}

/// `POST /garments/closet-analysis` result: how well a garment (saved or
/// not) pairs with the current closet. Recomputed on every call, never
/// stored by the backend.
class ClosetAnalysis {
  final ClosetAnalysisVersatility versatility;
  final List<ClosetAnalysisOutfitIdea> outfitIdeas;
  final List<ClosetAnalysisGarment> similarGarments;

  const ClosetAnalysis({
    required this.versatility,
    this.outfitIdeas = const [],
    this.similarGarments = const [],
  });

  factory ClosetAnalysis.fromJson(Map<String, dynamic> json) {
    return ClosetAnalysis(
      versatility: ClosetAnalysisVersatility.fromJson(
        (json['versatility'] as Map<String, dynamic>?) ?? const {},
      ),
      outfitIdeas:
          (json['outfit_ideas'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ClosetAnalysisOutfitIdea.fromJson)
              .toList() ??
          const [],
      similarGarments:
          (json['similar_garments'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ClosetAnalysisGarment.fromJson)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'versatility': versatility.toJson(),
    'outfit_ideas': outfitIdeas.map((i) => i.toJson()).toList(),
    'similar_garments': similarGarments.map((g) => g.toJson()).toList(),
  };
}
