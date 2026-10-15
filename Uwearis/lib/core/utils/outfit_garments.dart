import '../../data/garment.dart';
import '../services/garment_service.dart';
import 'debug_log.dart';
import 'signed_url.dart';

/// Unlisted categories (one-piece, socks) sort last.
const List<GarmentCategory> _garmentCategoryDisplayOrder = [
  GarmentCategory.top,
  GarmentCategory.bottom,
  GarmentCategory.outer,
  GarmentCategory.shoes,
  GarmentCategory.accessory,
];

/// Resolves an outfit's garments in display order, reusing [cached] unless
/// its signed URL expired. Pass the raw closet, not `.active`: deleted
/// garments must still resolve. A garment that fails to load is dropped.
Future<List<Garment>> loadOutfitGarments(
  Iterable<int> garmentIds, {
  required List<Garment> cached,
  required int outfitId,
}) async {
  final cachedById = {
    for (final g in cached)
      if (g.id != null) g.id!: g,
  };
  final results = await Future.wait(
    garmentIds.map((id) async {
      final cachedGarment = cachedById[id];
      final imageUrl = cachedGarment?.imageUrl;
      final isFresh =
          cachedGarment != null &&
          (imageUrl == null ||
              imageUrl.isEmpty ||
              !isSignedUrlExpired(imageUrl));
      if (isFresh) return cachedGarment;
      try {
        return await GarmentService().getGarment(id, includeDeleted: true);
      } catch (e) {
        debugLog('Failed to load garment $id for outfit $outfitId: $e');
        return null;
      }
    }),
  );
  return _sortGarmentsByCategory(results.whereType<Garment>());
}

List<Garment> _sortGarmentsByCategory(Iterable<Garment> garments) {
  int rank(Garment g) {
    final index = _garmentCategoryDisplayOrder.indexOf(g.category);
    return index == -1 ? _garmentCategoryDisplayOrder.length : index;
  }

  // List.sort isn't stable; tie-break on the original index.
  final indexed = garments.toList();
  final order = List<int>.generate(indexed.length, (i) => i)
    ..sort((a, b) {
      final cmp = rank(indexed[a]).compareTo(rank(indexed[b]));
      return cmp != 0 ? cmp : a.compareTo(b);
    });
  return [for (final i in order) indexed[i]];
}
