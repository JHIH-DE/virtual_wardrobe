import 'garment.dart';

/// One row of a garment's versatility breakdown: how many closet items of
/// [category] it pairs with, plus their ids (for the row's preview
/// thumbnails and the "see all" grid).
class VersatilityCategory {
  final GarmentCategory category;
  final int compatibleCount;
  final List<int> compatibleGarmentIds;

  const VersatilityCategory({
    required this.category,
    required this.compatibleCount,
    this.compatibleGarmentIds = const [],
  });

  factory VersatilityCategory.fromJson(Map<String, dynamic> json) {
    return VersatilityCategory(
      category: GarmentCategoryX.fromApiValue(json['category'] as String?),
      compatibleCount: (json['compatible_count'] as num?)?.toInt() ?? 0,
      compatibleGarmentIds:
          (json['compatible_garment_ids'] as List?)
              ?.whereType<num>()
              .map((n) => n.toInt())
              .toList() ??
          const [],
    );
  }
}

/// A garment's AI-assessed versatility (`GarmentService.analyzeGarment`) — an
/// overall [score] (0–100, null while the backend hasn't scored it yet) plus
/// a per-category [breakdown] of what it pairs with.
class Versatility {
  final int? score;
  final List<VersatilityCategory> breakdown;

  const Versatility({this.score, this.breakdown = const []});

  factory Versatility.fromJson(Map<String, dynamic> json) {
    return Versatility(
      score: (json['score'] as num?)?.toInt(),
      breakdown:
          (json['breakdown'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(VersatilityCategory.fromJson)
              .toList() ??
          const [],
    );
  }
}
