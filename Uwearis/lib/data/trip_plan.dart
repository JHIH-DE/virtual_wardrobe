import 'garment.dart';

/// One trip day's primary outfit — either an *already tried-on* result
/// (from `TripService.getTrip`'s `days[].outfits[]`, resolved against the
/// closet by [TripPlan.fromRenderedResponse]) or an AI-suggested option
/// nobody's rendered yet (from `getTripPlan` / `generateTripPlan`'s
/// `days[].options[]`, self-contained). Both parse into this same shape so
/// the page doesn't need to care which one a given day came from.
class TripDayOutfit {
  /// This day's own date, straight from `day['date']` — the day selector and
  /// header label read this instead of computing a date from the trip's
  /// overall span + list index, since the backend's `days[]` isn't
  /// guaranteed to tile that span with zero gaps.
  final DateTime? date;
  final int? optionId;
  final List<Garment> garments;
  final int? outfitId;
  final String? resultImageUrl;
  final double? temperatureMaxC;
  final double? temperatureMinC;

  /// Sticky across garment edits — unlike [outfitId] (which the backend
  /// clears the moment this day's garments change), this never resets once
  /// true. Its only job is telling "Generate Outfit" (never rendered
  /// before) apart from "Regenerate Outfit" (this slot had an image once).
  final bool everHadOutfit;

  const TripDayOutfit({
    this.date,
    this.optionId,
    this.garments = const [],
    this.outfitId,
    this.resultImageUrl,
    this.temperatureMaxC,
    this.temperatureMinC,
    this.everHadOutfit = false,
  });

  /// A day carrying just a date + temperature — no plan / outfit yet.
  static TripDayOutfit _empty(Map<String, dynamic> day) => TripDayOutfit(
    date: DateTime.tryParse((day['date'] as String?) ?? ''),
    temperatureMaxC: (day['temperature_max_c'] as num?)?.toDouble(),
    temperatureMinC: (day['temperature_min_c'] as num?)?.toDouble(),
  );

  /// From `getTrip`'s `days[].outfits[]` — an entry here only carries
  /// `garment_ids`, so [closetById] (the user's full closet) resolves them.
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
    );
  }

  /// From `getTripPlan` / `generateTripPlan`'s `days[].options[]` — the
  /// primary (lowest `order_index`) option, whose items embed their own
  /// image/name/category so no closet lookup is needed.
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
    );
  }
}

/// The parts of a trip plan Trip Details actually renders: one
/// [TripDayOutfit] per day plus the suitcase's garment ids. Built from
/// either the plan view (`getTripPlan` / `generateTripPlan`) or the
/// rendered view (`getTrip`).
class TripPlan {
  final List<TripDayOutfit> days;
  final Set<int> suitcaseIds;

  const TripPlan({this.days = const [], this.suitcaseIds = const {}});

  /// `getTripPlan` / `generateTripPlan` — every day's suggested options,
  /// self-contained.
  factory TripPlan.fromPlanResponse(Map<String, dynamic> data) {
    return TripPlan(
      days: ((data['days'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TripDayOutfit.fromPlanDay)
          .toList(),
      suitcaseIds: parseSuitcaseItemIds(data['suitcase_items']),
    );
  }

  /// `getTrip` — only already-rendered outfits, whose garments are ids that
  /// need resolving against [closetGarments].
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

/// What a `generate` / `regenerate` option-outfit render returns — just
/// the freshly-rendered `outfit_id` and its (15-minute) signed
/// `result_image_url`.
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
