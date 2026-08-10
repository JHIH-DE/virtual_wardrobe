/// What `AddOutfitPage` pops back on success when generating a new version
/// of an existing outfit (`existingOutfit` mode) — the generated image, the
/// backend `look_id` that produced it (so the caller can offer deleting
/// this specific version later, see `OutfitService.deleteLook`), and the
/// accessories used (so the caller's Garment list can reflect this specific
/// version instead of the outfit's fixed core combo).
class OutfitVersionResult {
  final String imageUrl;
  final int? lookId;
  final List<int> accessoryGarmentIds;
  const OutfitVersionResult({
    required this.imageUrl,
    this.lookId,
    this.accessoryGarmentIds = const [],
  });
}
