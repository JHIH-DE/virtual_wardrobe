import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/outfit.dart';
import '../services/outfit_service.dart';

/// The `type: general` (user-saved) outfits a garment appears in, keyed by
/// garment id. `GET /outfits/by-garments` also returns daily/trip-generated
/// outfits — those are filtered out here so every caller (the "Used in
/// outfits" page and Garment Details' count tile) agrees on the number.
final garmentOutfitsProvider = FutureProvider.family<List<Outfit>, int>((
  ref,
  garmentId,
) async {
  final outfits = await OutfitService().getOutfitsByGarments([garmentId]);
  return outfits.where((o) => o.groupType == OutfitGroupType.general).toList();
});
