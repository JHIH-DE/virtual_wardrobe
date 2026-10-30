import '../core/utils/signed_url.dart';
import 'garment.dart';
import 'outfit.dart';

/// Backend `TripOutfitSource`: how a trip outfit came to exist. Whether
/// Refresh may replace it is a separate flag ([TripOutfit.isReplaceable]).
enum TripOutfitSource { savedOutfit, suggested, manual }

extension TripOutfitSourceApi on TripOutfitSource {
  String get apiValue => switch (this) {
    TripOutfitSource.savedOutfit => 'saved_outfit',
    TripOutfitSource.suggested => 'suggested',
    TripOutfitSource.manual => 'manual',
  };

  static TripOutfitSource fromApiValue(String? value) => switch (value) {
    'saved_outfit' => TripOutfitSource.savedOutfit,
    'manual' => TripOutfitSource.manual,
    _ => TripOutfitSource.suggested,
  };
}

/// Mirrors the backend's minimum for building any outfit (top + bottom or
/// one-piece, plus shoes; else `SUITCASE_INCOMPLETE`). UX only — the backend
/// decides.
bool isViableSuitcase(Iterable<Garment> suitcase) {
  final categories = {
    for (final g in suitcase)
      if (!g.isDeleted) g.category,
  };
  final hasTopAndBottom =
      categories.contains(GarmentCategory.top) &&
      categories.contains(GarmentCategory.bottom);
  return (hasTopAndBottom || categories.contains(GarmentCategory.onePiece)) &&
      categories.contains(GarmentCategory.shoes);
}

/// Backend `TripOutfitGenerateMode`.
enum TripOutfitGenerateMode { plan, more, refresh }

extension TripOutfitGenerateModeApi on TripOutfitGenerateMode {
  String get apiValue => switch (this) {
    TripOutfitGenerateMode.plan => 'plan',
    TripOutfitGenerateMode.more => 'more',
    TripOutfitGenerateMode.refresh => 'refresh',
  };
}

/// One outfit in a trip's collection — not tied to a date.
class TripOutfit {
  final int id;
  final TripOutfitSource source;

  /// The saved outfit version it was added from; never modified by the trip.
  final int? sourceOutfitId;
  final String? name;
  final List<String> reasoning;
  final bool isPinned;
  final bool isManuallyEdited;
  final bool isReplaceable;

  /// This trip outfit's own try-on render. Null while [resultImageUrl] may
  /// still show the source saved outfit's image (same garments only).
  final int? outfitId;

  /// Whose image [resultImageUrl] is — the cache key follows it.
  final int? imageOutfitId;
  final String? resultImageUrl;
  final List<Garment> garments;
  final bool isComplete;

  const TripOutfit({
    required this.id,
    required this.source,
    this.sourceOutfitId,
    this.name,
    this.reasoning = const [],
    this.isPinned = false,
    this.isManuallyEdited = false,
    this.isReplaceable = false,
    this.outfitId,
    this.imageOutfitId,
    this.resultImageUrl,
    this.garments = const [],
    this.isComplete = true,
  });

  /// Derived locally so a suitcase change shows up without a re-fetch.
  List<Garment> missingGarments(Set<int> suitcaseIds) => [
    for (final g in garments)
      if (g.isDeleted || !suitcaseIds.contains(g.id)) g,
  ];

  bool get hasImage => resultImageUrl?.isNotEmpty ?? false;

  factory TripOutfit.fromJson(Map<String, dynamic> json) {
    return TripOutfit(
      id: (json['id'] as num?)?.toInt() ?? 0,
      source: TripOutfitSourceApi.fromApiValue(json['source'] as String?),
      sourceOutfitId: (json['source_outfit_id'] as num?)?.toInt(),
      name: json['name'] as String?,
      reasoning: ((json['reasoning'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      isPinned: (json['is_pinned'] as bool?) ?? false,
      isManuallyEdited: (json['is_manually_edited'] as bool?) ?? false,
      isReplaceable: (json['is_replaceable'] as bool?) ?? false,
      outfitId: (json['outfit_id'] as num?)?.toInt(),
      imageOutfitId: (json['image_outfit_id'] as num?)?.toInt(),
      resultImageUrl: json['result_image_url'] as String?,
      garments: ((json['garments'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Garment.fromTripItemJson)
          .toList(),
      isComplete: (json['is_complete'] as bool?) ?? true,
    );
  }
}

/// A trip's outfit collection plus its suitcase — the state behind Trip
/// Details and the Suitcase page. Every collection endpoint returns all of it.
class TripOutfitCollection {
  final List<TripOutfit> outfits;
  final List<Garment> suitcase;

  /// The user's own outfits whose garments are all packed but that aren't in
  /// the trip yet. Suggestions only — never added automatically.
  final List<Outfit> savedCandidates;
  final int totalDays;
  final int suggestedMin;
  final int suggestedMax;

  const TripOutfitCollection({
    this.outfits = const [],
    this.suitcase = const [],
    this.savedCandidates = const [],
    this.totalDays = 0,
    this.suggestedMin = 0,
    this.suggestedMax = 0,
  });

  Set<int> get suitcaseIds => {
    for (final g in suitcase)
      if (g.id != null) g.id!,
  };

  Set<int> get addedSourceOutfitIds => {
    for (final o in outfits)
      if (o.sourceOutfitId != null) o.sourceOutfitId!,
  };

  int get savedOutfitCount =>
      outfits.where((o) => o.source == TripOutfitSource.savedOutfit).length;

  List<TripOutfit> get replaceableOutfits =>
      outfits.where((o) => o.isReplaceable).toList();

  bool get hasStaleImages => anySignedUrlExpired([
    for (final o in outfits) ...[
      o.resultImageUrl,
      for (final g in o.garments) g.imageUrl,
    ],
    for (final g in suitcase) g.imageUrl,
    for (final o in savedCandidates) o.imageUrl,
  ]);

  TripOutfitCollection copyWith({List<Garment>? suitcase}) =>
      TripOutfitCollection(
        outfits: outfits,
        suitcase: suitcase ?? this.suitcase,
        savedCandidates: savedCandidates,
        totalDays: totalDays,
        suggestedMin: suggestedMin,
        suggestedMax: suggestedMax,
      );

  factory TripOutfitCollection.fromJson(Map<String, dynamic> json) {
    final count = json['suggested_outfit_count'];
    return TripOutfitCollection(
      outfits: ((json['outfits'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TripOutfit.fromJson)
          .toList(),
      suitcase: ((json['suitcase_items'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Garment.fromTripItemJson)
          .toList(),
      savedCandidates: ((json['saved_candidates'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Outfit.fromJson)
          .toList(),
      totalDays: (json['total_days'] as num?)?.toInt() ?? 0,
      suggestedMin: count is Map ? (count['min'] as num?)?.toInt() ?? 0 : 0,
      suggestedMax: count is Map ? (count['max'] as num?)?.toInt() ?? 0 : 0,
    );
  }
}

/// `POST .../outfits/generate`: [generatedCount] 0 means no more suitable
/// combinations, not an error.
class TripOutfitGenerateResult {
  final TripOutfitCollection collection;
  final int generatedCount;
  final int replacedCount;

  const TripOutfitGenerateResult({
    required this.collection,
    this.generatedCount = 0,
    this.replacedCount = 0,
  });

  factory TripOutfitGenerateResult.fromJson(Map<String, dynamic> json) {
    return TripOutfitGenerateResult(
      collection: TripOutfitCollection.fromJson(json),
      generatedCount: (json['generated_count'] as num?)?.toInt() ?? 0,
      replacedCount: (json['replaced_count'] as num?)?.toInt() ?? 0,
    );
  }
}
