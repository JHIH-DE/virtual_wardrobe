/// The per-generation status/result object for an outfit response — the
/// backend now nests it under `looks[]` (an outfit can have multiple look
/// attempts) instead of returning `status`/`result_image_url`/
/// `error_message`/`finished_at` at the outfit's top level. Uses the first
/// entry — real `look_id` values aren't `0` (that was just Swagger's
/// placeholder example value), so this is positional, not a value match.
Map<String, dynamic>? primaryLookOf(Map<String, dynamic> json) {
  final looks = json['looks'];
  if (looks is List && looks.isNotEmpty) {
    final first = looks.first;
    if (first is Map<String, dynamic>) return first;
  }
  return null;
}

/// Finds a specific entry in an outfit's `looks[]` by its `look_id` — use
/// when watching a particular regenerated look (e.g. right after
/// `OutfitService.createLook`) rather than whichever entry
/// [primaryLookOf] happens to treat as current.
Map<String, dynamic>? lookById(Map<String, dynamic> json, int lookId) {
  final looks = json['looks'];
  if (looks is! List) return null;
  for (final item in looks) {
    if (item is Map<String, dynamic> && item['look_id'] == lookId) {
      return item;
    }
  }
  return null;
}

/// Every entry in an outfit's `looks[]` — the full generation history,
/// unlike [primaryLookOf] which only returns one. Use to populate a
/// carousel/history view instead of client-side-only accumulation.
List<Map<String, dynamic>> allLooksOf(Map<String, dynamic> json) {
  final looks = json['looks'];
  if (looks is! List) return const [];
  return looks.whereType<Map<String, dynamic>>().toList();
}

class Outfit {
  final int id;
  final String? name;
  final List<int> garmentIds;
  final String imageUrl;
  final List<String> seasons;
  final List<String> style;
  final String? advice;
  final String? errorMessage;
  final bool isFavorite;
  final bool isSaved;
  final DateTime createdAt;
  final DateTime? finishedAt;

  Outfit({
    required this.id,
    this.name,
    this.garmentIds = const [],
    required this.imageUrl,
    this.seasons = const <String>[],
    this.style = const <String>[],
    this.advice,
    this.errorMessage,
    this.isFavorite = false,
    this.isSaved = false,
    DateTime? createdAt,
    this.finishedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Outfit copyWith({bool? isFavorite, bool? isSaved, String? name}) {
    return Outfit(
      id: id,
      name: name ?? this.name,
      garmentIds: garmentIds,
      imageUrl: imageUrl,
      seasons: seasons,
      style: style,
      advice: advice,
      errorMessage: errorMessage,
      isFavorite: isFavorite ?? this.isFavorite,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt,
      finishedAt: finishedAt,
    );
  }

  factory Outfit.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    int parseId(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    List<int> parseIds(dynamic v) {
      if (v is List) {
        return v.map((e) => parseId(e)).toList();
      }
      return [];
    }

    List<String> parseStrings(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      if (v is String && v.isNotEmpty) return [v];
      return [];
    }

    final look = primaryLookOf(json);
    return Outfit(
      // Backend now returns the outfit's id as `outfit_id`; `job_id` is
      // kept as a fallback for any endpoint that hasn't migrated. Getting
      // this wrong is silent and severe — every outfit was resolving to id
      // 0, which collided cache keys (all list cards showed the same
      // cached image) and made every details-page refresh re-fetch outfit
      // 0 regardless of which outfit was actually opened.
      id: parseId(json['outfit_id'] ?? json['job_id']),
      name: json['name'] as String?,
      garmentIds: parseIds(json['garment_ids']),
      imageUrl: (look?['result_image_url'] ?? json['result_image_url']) ?? '',
      errorMessage: look?['error_message'] ?? json['error_message'],
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      finishedAt: parseDate(look?['finished_at'] ?? json['finished_at']),
      seasons: parseStrings(json['season']),
      style: parseStrings(json['style']),
      advice: look?['ai_notes'] ?? json['ai_notes'],
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      isSaved: json['is_saved'] == true || json['is_saved'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'job_id': id,
      'garment_ids': garmentIds,
      'result_image_url': imageUrl,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'season': seasons,
      'style': style,
      'ai_notes': advice,
    };
  }
}
