import 'dart:async';

import 'package:http/http.dart' as http;

import '../../data/outfit.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// Client for the daily outfit read endpoint — the day's shared `type:
/// "daily"` OutfitGroup is generated and rendered entirely server-side on
/// its own schedule now, so the app's only remaining job is to read
/// whatever's there, same [Outfit] model as `OutfitService`.
class DailyOutfitService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/daily_outfits';

  /// Fetches [targetDate]'s outfits (`yyyy-MM-dd`). Returns null if no plan
  /// exists yet for that date.
  Future<List<Outfit>?> getDailyOutfit(String targetDate) async {
    debugLog('--- getDailyOutfit: $targetDate ---');
    final uri = Uri.parse('$_baseUrl/$targetDate');
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'getDailyOutfit');
    final data = envelope['data'];
    if (data == null) return null;
    if (data is! Map<String, dynamic>) {
      throw Exception('getDailyOutfit: invalid response');
    }
    final outfits = data['outfits'];
    if (outfits is! List) {
      throw Exception('getDailyOutfit: response missing outfits list');
    }
    return outfits
        .whereType<Map<String, dynamic>>()
        .map(Outfit.fromJson)
        .toList();
  }
}
