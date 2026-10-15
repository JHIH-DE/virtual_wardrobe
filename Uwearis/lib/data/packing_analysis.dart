import 'garment.dart';

/// One category's row from `/trip_plans/{id}/packing-analysis`.
class PackingCategory {
  final GarmentCategory category;
  final int recommendedQuantity;
  final Set<int> suggestedGarmentIds;

  /// May arrive as a plain string or a list of lines — joined with newlines.
  final String reasoning;

  const PackingCategory({
    required this.category,
    required this.recommendedQuantity,
    required this.suggestedGarmentIds,
    required this.reasoning,
  });

  factory PackingCategory.fromJson(Map<String, dynamic> json) {
    final rawReasoning = json['reasoning'];
    final reasoning = rawReasoning is List
        ? rawReasoning.join('\n')
        : (rawReasoning is String ? rawReasoning : '');

    final rawIds = json['suggested_garment_ids'];

    return PackingCategory(
      category: GarmentCategoryX.fromApiValue(json['category'] as String?),
      recommendedQuantity: (json['recommended_quantity'] as num?)?.toInt() ?? 0,
      suggestedGarmentIds: rawIds is List
          ? rawIds.whereType<num>().map((n) => n.toInt()).toSet()
          : const {},
      reasoning: reasoning,
    );
  }
}

class PackingAnalysis {
  final String? overallAdvice;
  final List<PackingCategory> categories;

  const PackingAnalysis({this.overallAdvice, this.categories = const []});

  factory PackingAnalysis.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    return PackingAnalysis(
      overallAdvice: json['overall_advice'] as String?,
      categories: rawCategories is List
          ? rawCategories
                .whereType<Map<String, dynamic>>()
                .map(PackingCategory.fromJson)
                .toList()
          : const [],
    );
  }

  /// The "pack N items" target shown on Trip Details' Suitcase card.
  int get recommendedTotal =>
      categories.fold(0, (sum, c) => sum + c.recommendedQuantity);

  PackingCategory? forCategory(GarmentCategory category) {
    for (final c in categories) {
      if (c.category == category) return c;
    }
    return null;
  }
}
