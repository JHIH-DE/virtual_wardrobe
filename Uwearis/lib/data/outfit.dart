/// Stable per-outfit cache-key identity for [ImageCacheBust]/image widgets —
/// pass the same key everywhere a given outfit's rendered image is cached
/// or bumped so a regenerate in one place busts the cache everywhere else.
String outfitImageCacheKey(int outfitId) => 'outfit-job-$outfitId';

/// One outfit from the OutfitGroup + Outfit API (`/api/v1/outfit`). The
/// render result lives directly on the outfit itself (`result_image_url`/
/// `error_message`/`status`) — `regenerate` overwrites this same outfit's
/// image in place rather than creating a new version.
class Outfit {
  final int id;
  final int groupId;
  final String groupType;
  final String status;
  final String? name;
  final List<int> garmentIds;
  final String imageUrl;
  final List<String> seasons;
  final List<String> style;
  final String? errorMessage;
  final int? backgroundId;
  final bool isFavorite;

  /// Why the AI picked this option — only populated on daily-outfit reads
  /// ([DailyOutfitService.getDailyOutfit]); other outfit sources don't
  /// return it.
  final String? reasoning;

  /// How many versions this outfit's group actually has — only meaningful
  /// on the representative [Outfit] a flattened list like
  /// [OutfitService.getAllOutfits] returns (one card per group); every
  /// other source (e.g. [OutfitService.getOutfit]) has no sibling count to
  /// report, so it defaults to 1.
  final int versionCount;

  /// The group's chosen cover outfit id (see `PATCH /outfit/{group_id}`) —
  /// the same value on every [Outfit] in a group, not a per-outfit
  /// property. Null means "no explicit choice yet, use the backend's
  /// default (lowest `outfit_id` in the group)". Not part of `OutfitOut`
  /// itself — [OutfitService] attaches it from the group wrapper after
  /// parsing (see [getAllOutfits]/[getGroupOutfits]).
  final int? coverOutfitId;

  /// The group's own name (see `PATCH /outfit/{group_id}`) — same value on
  /// every [Outfit] in a group, distinct from [name] (this specific
  /// outfit's own name). Null until either the user sets one explicitly or
  /// the group's first rendered outfit auto-seeds it (backend behavior,
  /// one-time only). Not part of `OutfitOut` itself — [OutfitService]
  /// attaches it from the group wrapper after parsing (see
  /// [getAllOutfits]/[getGroupOutfits]).
  final String? groupName;

  Outfit({
    required this.id,
    this.groupId = 0,
    this.groupType = 'general',
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
    this.reasoning,
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
      reasoning: reasoning,
      coverOutfitId: clearCoverOutfitId
          ? null
          : (coverOutfitId ?? this.coverOutfitId),
      groupName: clearGroupName ? null : (groupName ?? this.groupName),
    );
  }

  factory Outfit.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    List<int> parseIds(dynamic v) {
      if (v is List) return v.map((e) => parseId(e)).toList();
      return [];
    }

    List<String> parseStrings(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty) return [v];
      return [];
    }

    // Robust reasoning parsing to handle both String and List from the API,
    // same as TripGarmentSelectionPage's advice parsing.
    String? parseReasoning(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).join('\n');
      if (v is String && v.isNotEmpty) return v;
      return null;
    }

    return Outfit(
      id: parseId(json['outfit_id']),
      groupId: parseId(json['group_id']),
      groupType: json['group_type'] as String? ?? 'general',
      status: json['status'] as String? ?? 'completed',
      name: json['name'] as String?,
      garmentIds: parseIds(json['garment_ids']),
      imageUrl: (json['result_image_url'] as String?) ?? '',
      seasons: parseStrings(json['season']),
      style: parseStrings(json['style']),
      errorMessage: json['error_message'] as String?,
      backgroundId: (json['background_id'] as num?)?.toInt(),
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      reasoning: parseReasoning(json['reasoning']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'outfit_id': id,
      'group_id': groupId,
      'group_type': groupType,
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
