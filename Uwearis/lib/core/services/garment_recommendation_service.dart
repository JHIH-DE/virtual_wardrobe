import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/occasion_type.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// Text-only outfit advice for Add Outfit's "Complete with AI" — given
/// whichever garments the user has already picked, the backend's AI fills
/// in the rest from the user's own wardrobe. Locking is purely a frontend
/// bookkeeping concept (which cards show a lock icon, which survive a
/// re-run); the backend has no notion of it, it just treats [garmentIds] as
/// a starting point to build the outfit around. Style is resolved silently
/// server-side from the user's own Style Taste analysis — never passed from
/// here. Never generates a Try-On image or creates any OutfitGroup/Outfit;
/// that stays behind `OutfitService.generateOutfit` / `TryOnMixin` only
/// (see CLAUDE.md's virtual try-on section).
///
/// Plain per-call service — holds no state, so no singleton (see the
/// service-layer rules in CLAUDE.md).
class GarmentRecommendationService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/outfit/advice';

  /// [excludeGarmentIds] force-excludes ids from the AI's pick — used to ask
  /// for a different suggestion than a previous call returned (accumulate
  /// ids across every re-run in the session, not just the last one, so a
  /// rejected suggestion doesn't resurface a few taps later). If an id
  /// appears in both [garmentIds] and [excludeGarmentIds], [garmentIds]
  /// wins — a forced-in item is never dropped by the exclude list.
  Future<List<int>> completeOutfit({
    required List<int> garmentIds,
    required OccasionType occasion,
    double? temperatureC,
    List<int> excludeGarmentIds = const [],
  }) async {
    debugLog(
      '--- completeOutfit: garmentIds=$garmentIds '
      'excludeGarmentIds=$excludeGarmentIds '
      'occasion=${occasion.outfitAdviceOccasion} ---',
    );
    final uri = Uri.parse(_baseUrl);
    final payload = <String, dynamic>{
      'occasion': occasion.outfitAdviceOccasion,
      'temperature_c': temperatureC,
      'garment_ids': garmentIds,
      'exclude_garment_ids': excludeGarmentIds,
    };
    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 45)),
    );
    final envelope = decodeMap(res, op: 'completeOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('completeOutfit: response missing outfit data object');
    }
    final ids = data['selected_garment_ids'];
    if (ids is! List) {
      throw Exception('completeOutfit: response missing selected_garment_ids');
    }
    return ids.map((id) => (id as num).toInt()).toList();
  }
}
