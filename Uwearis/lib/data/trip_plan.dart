import 'package:intl/intl.dart';

import 'garment.dart';

/// One trip day's primary outfit, parsed from either the plan view
/// (`days[].options[]`) or the rendered view (`days[].outfits[]`).
class TripDayOutfit {
  /// Read instead of deriving from the trip span + index: the backend's
  /// `days[]` may have gaps.
  final DateTime? date;
  final int? optionId;
  final List<Garment> garments;
  final int? outfitId;
  final String? resultImageUrl;
  final double? temperatureMaxC;
  final double? temperatureMinC;

  /// Picks "Generate" vs "Regenerate". Unlike [outfitId] (cleared by the
  /// backend when the garments change), the page carries this over.
  final bool everHadOutfit;

  /// Set by the backend once the user swaps this option's garments; never
  /// reset by a render.
  final bool isManuallyEdited;

  const TripDayOutfit({
    this.date,
    this.optionId,
    this.garments = const [],
    this.outfitId,
    this.resultImageUrl,
    this.temperatureMaxC,
    this.temperatureMinC,
    this.everHadOutfit = false,
    this.isManuallyEdited = false,
  });

  /// The Replan policy, in priority order:
  /// 1. A garment no longer in [suitcaseIds] → regenerate (overrides 2–3).
  /// 2. [isManuallyEdited] → keep.
  /// 3. Already rendered ([outfitId] set) → keep.
  /// 4. Otherwise → regenerate.
  bool needsReplan(Set<int> suitcaseIds) {
    final hasOrphanedGarment = garments.any(
      (g) => g.id != null && !suitcaseIds.contains(g.id),
    );
    if (hasOrphanedGarment) return true;
    if (isManuallyEdited) return false;
    if (outfitId != null) return false;
    return true;
  }

  /// A day carrying just a date + temperature — no plan / outfit yet.
  static TripDayOutfit _empty(Map<String, dynamic> day) => TripDayOutfit(
    date: DateTime.tryParse((day['date'] as String?) ?? ''),
    temperatureMaxC: (day['temperature_max_c'] as num?)?.toDouble(),
    temperatureMinC: (day['temperature_min_c'] as num?)?.toDouble(),
  );

  /// `days[].outfits[]` only carries `garment_ids`, resolved via [closetById].
  factory TripDayOutfit.fromRenderedDay(
    Map<String, dynamic> day,
    Map<int, Garment> closetById,
  ) {
    final outfits = ((day['outfits'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (outfits.isEmpty) return TripDayOutfit._empty(day);

    final primary = outfits.firstWhere(
      (o) => o['option_type'] == 'primary',
      orElse: () => outfits.first,
    );
    final garments = ((primary['garment_ids'] as List?) ?? [])
        .whereType<num>()
        .map((n) => closetById[n.toInt()])
        .whereType<Garment>()
        .toList();
    final outfitId = (primary['outfit_id'] as num?)?.toInt();

    return TripDayOutfit(
      date: DateTime.tryParse((day['date'] as String?) ?? ''),
      optionId: (primary['trip_option_id'] as num?)?.toInt(),
      garments: garments,
      outfitId: outfitId,
      resultImageUrl: primary['result_image_url'] as String?,
      temperatureMaxC: (day['temperature_max_c'] as num?)?.toDouble(),
      temperatureMinC: (day['temperature_min_c'] as num?)?.toDouble(),
      everHadOutfit: outfitId != null,
      isManuallyEdited: (primary['is_manually_edited'] as bool?) ?? false,
    );
  }

  /// Uses the lowest-`order_index` option; its items are self-contained.
  factory TripDayOutfit.fromPlanDay(Map<String, dynamic> day) {
    final options =
        ((day['options'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) => ((a['order_index'] as num?) ?? 0).compareTo(
              (b['order_index'] as num?) ?? 0,
            ),
          );
    if (options.isEmpty) return TripDayOutfit._empty(day);

    final primary = options.first;
    final garments = ((primary['items'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Garment.fromTripItemJson)
        .toList();
    final outfitId = (primary['outfit_id'] as num?)?.toInt();

    return TripDayOutfit(
      date: DateTime.tryParse((day['date'] as String?) ?? ''),
      optionId: (primary['id'] as num?)?.toInt(),
      garments: garments,
      outfitId: outfitId,
      resultImageUrl: primary['result_image_url'] as String?,
      temperatureMaxC: (day['temperature_max_c'] as num?)?.toDouble(),
      temperatureMinC: (day['temperature_min_c'] as num?)?.toDouble(),
      everHadOutfit: outfitId != null,
      isManuallyEdited: (primary['is_manually_edited'] as bool?) ?? false,
    );
  }
}

class TripPlan {
  final List<TripDayOutfit> days;
  final Set<int> suitcaseIds;

  const TripPlan({this.days = const [], this.suitcaseIds = const {}});

  factory TripPlan.fromPlanResponse(Map<String, dynamic> data) {
    return TripPlan(
      days: ((data['days'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TripDayOutfit.fromPlanDay)
          .toList(),
      suitcaseIds: parseSuitcaseItemIds(data['suitcase_items']),
    );
  }

  factory TripPlan.fromRenderedResponse(
    Map<String, dynamic> data,
    List<Garment> closetGarments,
  ) {
    final closetById = {
      for (final g in closetGarments)
        if (g.id != null) g.id!: g,
    };
    return TripPlan(
      days: ((data['days'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map((day) => TripDayOutfit.fromRenderedDay(day, closetById))
          .toList(),
      suitcaseIds: parseSuitcaseItemIds(data['suitcase_items']),
    );
  }
}

/// Result of a `generate` / `regenerate` option-outfit render.
class TripOptionRender {
  final int? outfitId;
  final String? resultImageUrl;

  const TripOptionRender({this.outfitId, this.resultImageUrl});

  factory TripOptionRender.fromJson(Map<String, dynamic> json) {
    return TripOptionRender(
      outfitId: (json['outfit_id'] as num?)?.toInt(),
      resultImageUrl: json['result_image_url'] as String?,
    );
  }
}

/// A plan option still using a garment just removed from the suitcase
/// (`affected_options`). Informational only — nothing is changed for it.
class TripAffectedOption {
  final int dayId;
  final DateTime? date;
  final int optionId;
  final bool isManuallyEdited;
  final bool hasRenderedOutfit;

  const TripAffectedOption({
    required this.dayId,
    this.date,
    required this.optionId,
    required this.isManuallyEdited,
    required this.hasRenderedOutfit,
  });

  factory TripAffectedOption.fromJson(Map<String, dynamic> json) {
    return TripAffectedOption(
      dayId: (json['day_id'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse((json['date'] as String?) ?? ''),
      optionId: (json['option_id'] as num?)?.toInt() ?? 0,
      isManuallyEdited: (json['is_manually_edited'] as bool?) ?? false,
      hasRenderedOutfit: (json['has_rendered_outfit'] as bool?) ?? false,
    );
  }
}

/// The `days` filter for `generateTripPlan`, shared by both Replan entry
/// points. Null when nothing needs replanning — skip the call.
List<Map<String, dynamic>>? daysToReplan(
  List<TripDayOutfit> days,
  Set<int> suitcaseIds,
) {
  final dates = [
    for (final day in days)
      if (day.date != null && day.needsReplan(suitcaseIds)) day.date!,
  ];
  if (dates.isEmpty) return null;
  return [
    for (final date in dates) {'date': DateFormat('yyyy-MM-dd').format(date)},
  ];
}

/// `suitcase_items` comes back either as `{garment_id: int, ...}` objects or
/// bare ints.
Set<int> parseSuitcaseItemIds(dynamic rawItems) {
  final ids = <int>{};
  if (rawItems is List) {
    for (final item in rawItems) {
      if (item is Map && item['garment_id'] is num) {
        ids.add((item['garment_id'] as num).toInt());
      } else if (item is num) {
        ids.add(item.toInt());
      }
    }
  }
  return ids;
}
