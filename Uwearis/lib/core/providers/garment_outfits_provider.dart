import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/outfit.dart';
import '../services/outfit_service.dart';
import 'retry_policy.dart';

/// The user-saved (`general`) outfits a garment appears in.
/// `GET /outfit/by-garments` also returns trip outfits; they're dropped here
/// so every caller agrees on the count.
final garmentOutfitsProvider = FutureProvider.family<List<Outfit>, int>((
  ref,
  garmentId,
) async {
  final outfits = await OutfitService().getOutfitsByGarments([garmentId]);
  return outfits.where((o) => o.groupType == OutfitGroupType.general).toList();
}, retry: appRetryPolicy);
