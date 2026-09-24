import 'garment.dart';

/// One AI-suggested option from a day's daily-outfit plan — primary or one
/// of its alternatives — from `DailyOutfitService.generate`/
/// `generateOptionOutfit`. [items] embed their own name/category/image (no
/// closet lookup needed), same shape [TripDayOutfit.fromPlanDay] already
/// parses via [Garment.fromTripItemJson].
class DailyOutfitOption {
  final int id;
  final int dailyOutfitId;
  final int orderIndex;
  final String optionType;
  final String? displayName;
  final String? reasoning;

  /// The rendered [Outfit.id] for this option, once tried on — null until
  /// [DailyOutfitService.generateOptionOutfit] has been called for it.
  final int? outfitId;

  /// 15-minute signed GCS URL — same caveat as every other daily/trip
  /// render: re-fetch via [DailyOutfitService.getDailyOutfit] rather than
  /// caching this past that window.
  final String? resultImageUrl;
  final List<Garment> items;

  const DailyOutfitOption({
    required this.id,
    required this.dailyOutfitId,
    this.orderIndex = 0,
    this.optionType = 'primary',
    this.displayName,
    this.reasoning,
    this.outfitId,
    this.resultImageUrl,
    this.items = const [],
  });

  bool get isPrimary => optionType == 'primary';

  factory DailyOutfitOption.fromJson(Map<String, dynamic> json) {
    // Same String-or-List tolerance as Outfit.fromJson's own reasoning
    // parsing — the AI response shape isn't guaranteed consistent between
    // endpoints.
    String? parseReasoning(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).join('\n');
      if (v is String && v.isNotEmpty) return v;
      return null;
    }

    return DailyOutfitOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      dailyOutfitId: (json['daily_outfit_id'] as num?)?.toInt() ?? 0,
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      optionType: json['option_type'] as String? ?? 'primary',
      displayName: json['display_name'] as String?,
      reasoning: parseReasoning(json['reasoning']),
      outfitId: (json['outfit_id'] as num?)?.toInt(),
      resultImageUrl: json['result_image_url'] as String?,
      items: ((json['items'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Garment.fromTripItemJson)
          .toList(),
    );
  }
}

/// A day's full daily-outfit plan — `POST /daily_outfits/generate`'s
/// response. [groupId] mirrors the day's shared try-on `OutfitGroup` at the
/// moment this plan was generated (usually `null` right after a fresh
/// generate, before anything's been tried on) — once something has been
/// tried on, [DailyOutfitService.getDailyOutfit] is the source of truth for
/// the day's actual rendered outfits, not this snapshot.
class DailyOutfitPlan {
  final int id;
  final DateTime? date;
  final String? occasion;
  final double? temperatureC;
  final List<DailyOutfitOption> options;
  final int? groupId;

  const DailyOutfitPlan({
    required this.id,
    this.date,
    this.occasion,
    this.temperatureC,
    this.options = const [],
    this.groupId,
  });

  /// The `option_type: "primary"` entry, falling back to the first option
  /// if the backend ever omits that tag — same defensive shape
  /// [TripDayOutfit.fromPlanDay] uses for its own primary-option lookup.
  DailyOutfitOption? get primaryOption {
    if (options.isEmpty) return null;
    for (final option in options) {
      if (option.isPrimary) return option;
    }
    return options.first;
  }

  factory DailyOutfitPlan.fromJson(Map<String, dynamic> json) {
    return DailyOutfitPlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse((json['date'] as String?) ?? ''),
      occasion: json['occasion'] as String?,
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      options: ((json['options'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DailyOutfitOption.fromJson)
          .toList(),
      groupId: (json['group_id'] as num?)?.toInt(),
    );
  }
}
