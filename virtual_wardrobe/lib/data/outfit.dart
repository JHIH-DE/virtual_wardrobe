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
  });

  Outfit copyWith({
    bool? isFavorite,
    String? name,
    String? imageUrl,
    List<String>? seasons,
    List<String>? style,
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
