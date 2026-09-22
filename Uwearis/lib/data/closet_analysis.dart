import 'garment.dart';

/// The five fixed bands `POST /garments/{id}/closet-analysis` derives from
/// its 1–10 `level` — the backend computes this deterministically from the
/// number, so Flutter never sees a value outside this set (see
/// garments-api.md §8).
enum VersatilityLabel { veryLimited, limited, moderate, versatile, highlyVersatile }

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

/// A garment's closet-fit assessment — a 1–10 [level] plus the
/// backend-derived [label] band. Recomputed fresh on every
/// `closet-analysis` call; not a stored/permanent garment property (see
/// [ClosetAnalysis]'s own doc comment). The backend dropped the explanatory
/// `summary` string this used to carry — there is no replacement field.
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

  /// Mirrors the API's own field shape, so a persisted cache entry
  /// round-trips through [fromJson] unchanged — see
  /// `GarmentService`'s closet-analysis cache.
  Map<String, dynamic> toJson() => {'level': level, 'label': label.apiValue};
}

/// One garment as it appears inside an [ClosetAnalysisOutfitIdea] or
/// [ClosetAnalysis.similarGarments] — a lightweight projection embedded
/// straight in the closet-analysis response (not the full [Garment]
/// shape), so callers don't need to cross-reference the closet just to
/// render a thumbnail. [isTarget] only ever appears set inside an outfit
/// idea's own garment list (the analyzed garment itself); it's always
/// false for a `similar_garments` entry.
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

/// One suggested outfit built from the user's own closet around the
/// analyzed garment — up to 3 of these ride along on a closet-analysis
/// response. Display-only in this app: nothing here creates an `Outfit` or
/// triggers a try-on render.
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

/// `POST /garments/{id}/closet-analysis`'s result — how well an
/// already-in-the-closet garment pairs with the user's *current* full
/// closet: a [versatility] rating, up to 3 [outfitIdeas] built around it,
/// and up to 3 [similarGarments] already owned. Not written to the DB and
/// not a permanent garment property — the backend recomputes it fresh on
/// every call, so it can change as the closet changes (see
/// garments-api.md §8). Superseded the old, now-removed
/// `POST /garments/versatility-score` (a 1–100 score for a not-yet-created
/// garment); this replaces that model entirely — no field maps 1:1.
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
