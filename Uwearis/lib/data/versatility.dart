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

/// A garment's AI-assessed versatility (`GarmentService.scoreVersatility`) —
/// an overall [score] (1–100) plus a per-category [breakdown] of what it
/// pairs with. When the backend couldn't score it, [score] and [breakdown]
/// are null and [skippedReason]/[message] explain why (empty closet, unknown
/// category, AI/DB failure — see the versatility-score API).
class Versatility {
  final int? score;
  final int? combinationCount;
  final String? skippedReason;
  final String? message;
  final List<VersatilityCategory> breakdown;

  const Versatility({
    this.score,
    this.combinationCount,
    this.skippedReason,
    this.message,
    this.breakdown = const [],
  });

  factory Versatility.fromJson(Map<String, dynamic> json) {
    return Versatility(
      score: (json['score'] as num?)?.toInt(),
      combinationCount: (json['combination_count'] as num?)?.toInt(),
      skippedReason: json['skipped_reason'] as String?,
      message: json['message'] as String?,
      breakdown:
          (json['breakdown'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(VersatilityCategory.fromJson)
              .toList() ??
          const [],
    );
  }
}
