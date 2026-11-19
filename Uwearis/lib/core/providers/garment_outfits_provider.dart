import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/outfit.dart';
import '../services/outfit_service.dart';
import 'retry_policy.dart';

/// The user-saved (`general`) outfits a garment appears in.
/// `GET /outfit/by-garments` also returns trip outfits; they're dropped here
/// so every caller agrees on the count. Re-fetched on
/// [OutfitService.garmentLinkChanges] — lazily, unless something listens.
final garmentOutfitsProvider = FutureProvider.family<List<Outfit>, int>((
  ref,
  garmentId,
) async {
  final changes = OutfitService.garmentLinkChanges.listen(
    (_) => ref.invalidateSelf(),
  );
  ref.onDispose(changes.cancel);
  final outfits = await OutfitService().getOutfitsByGarments([garmentId]);
  return outfits.where((o) => o.groupType == OutfitGroupType.general).toList();
}, retry: appRetryPolicy);
