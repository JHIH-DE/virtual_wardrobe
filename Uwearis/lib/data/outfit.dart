import '../core/utils/image_cache_bust.dart';

/// Base key for [ImageCacheBust]; widgets use [outfitImageVersionedCacheKey].
String outfitImageCacheKey(int outfitId) => 'outfit-job-$outfitId';

/// The cache key every outfit image widget should use, so a regenerate bump
/// anywhere is seen everywhere.
String outfitImageVersionedCacheKey(int outfitId) {
  final baseKey = outfitImageCacheKey(outfitId);
  return '$baseKey-v${ImageCacheBust.versionOf(baseKey)}';
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
class Outfit {
  final int id;
  final int groupId;
  final OutfitGroupType groupType;
  final String status;
  final String? name;
  final List<int> garmentIds;
  final String imageUrl;
  final List<String> seasons;
  final List<String> style;
  final String? errorMessage;
  final int? backgroundId;
  final bool isFavorite;

  /// Versions in this outfit's group — only set on the per-group
  /// representatives `OutfitService.getAllOutfits` returns; 1 elsewhere.
  final int versionCount;

  /// Group-level cover choice, attached by `OutfitService` from the group
  /// wrapper (not in `OutfitOut`). Null = backend default (lowest id).
  final int? coverOutfitId;

  /// Group-level name (distinct from [name]), attached by `OutfitService`
  /// from the group wrapper. The backend seeds it once from the first
  /// rendered outfit.
  final String? groupName;

  Outfit({
    required this.id,
    this.groupId = 0,
    this.groupType = OutfitGroupType.general,
    this.status = 'completed',
    this.name,
    this.garmentIds = const [],
    required this.imageUrl,
    this.seasons = const <String>[],
    this.style = const <String>[],
    this.errorMessage,
    this.backgroundId,
    this.isFavorite = false,
    this.versionCount = 1,
    this.coverOutfitId,
    this.groupName,
  });

  Outfit copyWith({
    bool? isFavorite,
    String? name,
    String? imageUrl,
    List<String>? seasons,
    List<String>? style,
    int? versionCount,
    int? coverOutfitId,
    bool clearCoverOutfitId = false,
    String? groupName,
    bool clearGroupName = false,
  }) {
    return Outfit(
      id: id,
      groupId: groupId,
      groupType: groupType,
      status: status,
      name: name ?? this.name,
      garmentIds: garmentIds,
      imageUrl: imageUrl ?? this.imageUrl,
      seasons: seasons ?? this.seasons,
      style: style ?? this.style,
      errorMessage: errorMessage,
      backgroundId: backgroundId,
      isFavorite: isFavorite ?? this.isFavorite,
      versionCount: versionCount ?? this.versionCount,
      coverOutfitId: clearCoverOutfitId
          ? null
          : (coverOutfitId ?? this.coverOutfitId),
      groupName: clearGroupName ? null : (groupName ?? this.groupName),
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
      seasons: parseStrings(json['season']),
      style: parseStrings(json['style']),
      errorMessage: json['error_message'] as String?,
      backgroundId: (json['background_id'] as num?)?.toInt(),
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
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
    };
  }
}
