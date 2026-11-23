import 'outfit.dart';

/// Backend `OutfitGroup`: one outfit idea and every rendered version of it.
/// Name and cover belong to the group; everything else is per version.
class OutfitGroup {
  final int groupId;
  final OutfitGroupType type;
  final String? name;

  /// The version the user picked to stand for the group, or null for the
  /// backend's default (see [groupRepresentative]).
  final int? coverOutfitId;
  final List<Outfit> versions;

  const OutfitGroup({
    required this.groupId,
    this.type = OutfitGroupType.general,
    this.name,
    this.coverOutfitId,
    required this.versions,
  });

  /// A group item of `GET /outfit` or the body of `GET /outfit/{group_id}`;
  /// [groupId] stands in when the body omits `group_id`.
  factory OutfitGroup.fromJson(Map<String, dynamic> json, {int? groupId}) {
    final outfits = json['outfits'];
    return OutfitGroup(
      groupId: (json['group_id'] as num?)?.toInt() ?? groupId ?? 0,
      type: OutfitGroupTypeApi.fromApiValue(json['type'] as String?),
      name: json['name'] as String?,
      coverOutfitId: (json['cover_outfit_id'] as num?)?.toInt(),
      versions: outfits is List
          ? outfits
                .whereType<Map<String, dynamic>>()
                .map(Outfit.fromJson)
                .toList()
          : const [],
    );
  }

  OutfitGroup copyWith({String? name, List<Outfit>? versions}) => OutfitGroup(
    groupId: groupId,
    type: type,
    name: name ?? this.name,
    coverOutfitId: coverOutfitId,
    versions: versions ?? this.versions,
  );

  /// Null only for a group with no versions left.
  Outfit? get cover =>
      versions.isEmpty ? null : groupRepresentative(versions, coverOutfitId);

  int get versionCount => versions.length;
}
