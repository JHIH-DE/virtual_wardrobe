class Look {
  final int id;
  final String? name;
  final List<int> garmentIds;
  final String imageUrl;
  final List<String> seasons;
  final List<String> style;
  final String? advice;
  final String? errorMessage;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime? finishedAt;

  Look({
    required this.id,
    this.name,
    this.garmentIds = const [],
    required this.imageUrl,
    this.seasons = const <String>[],
    this.style = const <String>[],
    this.advice,
    this.errorMessage,
    this.isFavorite = false,
    DateTime? createdAt,
    this.finishedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Look copyWith({bool? isFavorite, String? name}) {
    return Look(
      id: id,
      name: name ?? this.name,
      garmentIds: garmentIds,
      imageUrl: imageUrl,
      seasons: seasons,
      style: style,
      advice: advice,
      errorMessage: errorMessage,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      finishedAt: finishedAt,
    );
  }

  factory Look.fromJson(Map<String, dynamic> json) {
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

    return Look(
      id: parseId(json['job_id']),
      name: json['name'] as String?,
      garmentIds: parseIds(json['garment_ids']),
      imageUrl: json['result_image_url'] ?? '',
      errorMessage: json['error_message'],
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      finishedAt: parseDate(json['finished_at']),
      seasons: parseStrings(json['season']),
      style: parseStrings(json['style']),
      advice: json['ai_notes'],
      isFavorite: json['is_favorite'] == true,
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
