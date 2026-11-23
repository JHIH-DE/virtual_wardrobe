import '../core/utils/image_cache_bust.dart';

/// Base key for [ImageCacheBust]; widgets use [outfitImageVersionedCacheKey].
String outfitImageCacheKey(int outfitId) => 'outfit-job-$outfitId';

/// The cache key every outfit image widget should use, so a regenerate bump
/// anywhere is seen everywhere.
String outfitImageVersionedCacheKey(int outfitId) {
  final baseKey = outfitImageCacheKey(outfitId);
  return '$baseKey-v${ImageCacheBust.versionOf(baseKey)}';
}

/// The version that stands for its group: the one [coverOutfitId] names,
/// or — when it is null or names none of [versions] — the lowest id (the
/// backend's own default, the group's earliest-created outfit). Throws
/// [StateError] for an empty [versions].
Outfit groupRepresentative(List<Outfit> versions, int? coverOutfitId) {
  Outfit lowestId() => versions.reduce((a, b) => a.id < b.id ? a : b);
  if (coverOutfitId == null) return lowestId();
  return versions.firstWhere((o) => o.id == coverOutfitId, orElse: lowestId);
}

/// Backend `OutfitGroupType`; shared by every outfit in a group.
enum OutfitGroupType { general, trip }

extension OutfitGroupTypeApi on OutfitGroupType {
  String get apiValue => switch (this) {
    OutfitGroupType.general => 'general',
    OutfitGroupType.trip => 'trip',
  };

  static OutfitGroupType fromApiValue(String? value) => switch (value) {
    'trip' => OutfitGroupType.trip,
    _ => OutfitGroupType.general,
  };
}

/// One outfit from `/api/v1/outfit`. `regenerate` overwrites its image in
/// place rather than creating a new version.
/// An outfit's suitable temperature: `[minC, maxC)`, null = open end.
typedef OutfitTemperature = ({
  int? minC,
  int? maxC,
  OutfitTemperatureSource source,
});

/// What a PATCH sends for the suitable temperature: a manual range, or both
/// null to go back to the automatic one.
typedef OutfitTemperatureEdit = ({int? minC, int? maxC});

enum OutfitTemperatureSource {
  /// Calculated from the garments; follows garment edits.
  auto('auto'),

  /// Set by the user.
  manual('manual');

  final String apiValue;
  const OutfitTemperatureSource(this.apiValue);

  static OutfitTemperatureSource? fromApiValue(String? value) {
    for (final s in values) {
      if (s.apiValue == value) return s;
    }
    return null;
  }
}

class Outfit {
  final int id;
  final int groupId;
  final OutfitGroupType groupType;
  final String status;
  final String? name;
  final List<int> garmentIds;
  final String imageUrl;

  /// Backend-derived stable cache key for [imageUrl]; prefer it over the
  /// local version-counter key wherever one is available.
  final String? resultImageCacheKey;
  final List<String> seasons;
  final List<String> style;
  final String? errorMessage;
  final int? backgroundId;
  final bool isFavorite;

  /// Day-average °C range the daily pick accepts this outfit for,
  /// `[min, max)`; null = open on that side.
  final int? suitableTempMinC;
  final int? suitableTempMaxC;

  /// A manual range is never recalculated from the garments.
  final OutfitTemperatureSource suitableTempSource;

  OutfitTemperature get suitableTemperature => (
    minC: suitableTempMinC,
    maxC: suitableTempMaxC,
    source: suitableTempSource,
  );

  Outfit({
    required this.id,
    this.groupId = 0,
    this.groupType = OutfitGroupType.general,
    this.status = 'completed',
    this.name,
    this.garmentIds = const [],
    required this.imageUrl,
    this.resultImageCacheKey,
    this.seasons = const <String>[],
    this.style = const <String>[],
    this.errorMessage,
    this.backgroundId,
    this.isFavorite = false,
    this.suitableTempMinC,
    this.suitableTempMaxC,
    this.suitableTempSource = OutfitTemperatureSource.auto,
  });

  /// The cache key every widget displaying this outfit's image should use:
  /// the backend's own [resultImageCacheKey] when available, else the local
  /// version-counter fallback.
  String get displayImageCacheKey =>
      imageCacheKey(resultImageCacheKey, outfitImageVersionedCacheKey(id))!;

  Outfit copyWith({
    bool? isFavorite,
    String? name,
    String? imageUrl,
    String? resultImageCacheKey,
    List<String>? seasons,
    List<String>? style,
    OutfitTemperature? suitableTemperature,
  }) {
    return Outfit(
      id: id,
      groupId: groupId,
      groupType: groupType,
      status: status,
      name: name ?? this.name,
      garmentIds: garmentIds,
      imageUrl: imageUrl ?? this.imageUrl,
      resultImageCacheKey: resultImageCacheKey ?? this.resultImageCacheKey,
      seasons: seasons ?? this.seasons,
      style: style ?? this.style,
      errorMessage: errorMessage,
      backgroundId: backgroundId,
      isFavorite: isFavorite ?? this.isFavorite,
      suitableTempMinC: suitableTemperature != null
          ? suitableTemperature.minC
          : suitableTempMinC,
      suitableTempMaxC: suitableTemperature != null
          ? suitableTemperature.maxC
          : suitableTempMaxC,
      suitableTempSource: suitableTemperature?.source ?? suitableTempSource,
    );
  }

  factory Outfit.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    // Entries may be bare ids or `{garment_id|id: ...}` objects. Unparseable
    // ones are dropped rather than defaulted to a nonexistent id 0.
    int? parseGarmentId(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      if (v is Map) {
        final id = v['garment_id'] ?? v['id'];
        if (id is num) return id.toInt();
        if (id is String) return int.tryParse(id);
      }
      return null;
    }

    List<int> parseIds(dynamic v) {
      if (v is List) return v.map(parseGarmentId).whereType<int>().toList();
      return [];
    }

    List<String> parseStrings(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty) return [v];
      return [];
    }

    return Outfit(
      id: parseId(json['outfit_id']),
      groupId: parseId(json['group_id']),
      groupType: OutfitGroupTypeApi.fromApiValue(json['group_type'] as String?),
      status: json['status'] as String? ?? 'completed',
      name: json['name'] as String?,
      garmentIds: parseIds(json['garment_ids']),
      imageUrl: (json['result_image_url'] as String?) ?? '',
      resultImageCacheKey: json['result_image_cache_key'] as String?,
      seasons: parseStrings(json['season']),
      style: parseStrings(json['style']),
      errorMessage: json['error_message'] as String?,
      backgroundId: (json['background_id'] as num?)?.toInt(),
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      suitableTempMinC: (json['suitable_temp_min_c'] as num?)?.toInt(),
      suitableTempMaxC: (json['suitable_temp_max_c'] as num?)?.toInt(),
      suitableTempSource:
          OutfitTemperatureSource.fromApiValue(
            json['suitable_temp_source'] as String?,
          ) ??
          OutfitTemperatureSource.auto,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outfit_id': id,
      'group_id': groupId,
      'group_type': groupType.apiValue,
      'status': status,
      'name': name,
      'garment_ids': garmentIds,
      'result_image_url': imageUrl,
      'season': seasons,
      'style': style,
      'error_message': errorMessage,
      'background_id': backgroundId,
      'is_favorite': isFavorite,
      'suitable_temp_min_c': suitableTempMinC,
      'suitable_temp_max_c': suitableTempMaxC,
      'suitable_temp_source': suitableTempSource.apiValue,
    };
  }
}

/// What [target] shows while [edit] is being saved: a manual range at once;
/// a reset to automatic keeps the current numbers until the reply.
OutfitTemperature optimisticOutfitTemperature(
  Outfit target,
  OutfitTemperatureEdit? edit,
) {
  if (edit == null || (edit.minC == null && edit.maxC == null)) {
    return target.suitableTemperature;
  }
  return (
    minC: edit.minC,
    maxC: edit.maxC,
    source: OutfitTemperatureSource.manual,
  );
}
