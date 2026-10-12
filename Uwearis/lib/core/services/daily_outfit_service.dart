import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../data/outfit.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// Client for the `/daily_outfits` API — a day's plan whose options each
/// point at one of the user's own `general` outfits, picked server-side by
/// rules (weather, occasion, recent wear) rather than AI-generated, so no
/// try-on render or daily quota is involved. Nothing generates a plan in
/// the background: [generate] (called by `DailyOutfitNotifier` when today
/// has none) is the only way a date gets one; both it and [getDailyOutfit]
/// return the day's picked outfits.
class DailyOutfitService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/daily_outfits';

  /// Fetches [targetDate]'s outfits (`yyyy-MM-dd`). Returns null if no plan
  /// exists yet for that date.
  Future<List<Outfit>?> getDailyOutfit(String targetDate) async {
    debugLog('--- getDailyOutfit: $targetDate ---');
    final uri = Uri.parse('$_baseUrl/$targetDate');
    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );
    final envelope = decodeMap(res, op: 'getDailyOutfit');
    final data = envelope['data'];
    if (data == null) {
      debugLog('getDailyOutfit: $targetDate -> data is null (no plan yet)');
      return null;
    }
    if (data is! Map<String, dynamic>) {
      throw Exception('getDailyOutfit: invalid response');
    }
    return _parseOutfits(data, op: 'getDailyOutfit');
  }

  /// The `outfits` list both [getDailyOutfit] and [generate] return — the
  /// day's picked outfits in option order, as plain `OutfitOut`s.
  List<Outfit> _parseOutfits(Map<String, dynamic> data, {required String op}) {
    final outfits = data['outfits'];
    if (outfits is! List) {
      throw Exception('$op: response missing outfits list');
    }
    final result = outfits
        .whereType<Map<String, dynamic>>()
        .map(Outfit.fromJson)
        .toList();
    debugLog('$op: ${outfits.length} raw, ${result.length} parsed');
    return result;
  }

  /// Picks (or, for a date that already has one, entirely overwrites)
  /// [date]'s outfit plan from the user's own outfits and returns the picked
  /// outfits — the same list a [getDailyOutfit] right after would return,
  /// so there's no need to read it back separately. Overwriting only
  /// drops the old option rows; the outfits they pointed at are untouched.
  /// Picking is randomized, so calling again usually returns a different
  /// set.
  ///
  /// [occasion] left null reuses whatever occasion is already stored for
  /// [date], falling back to `casual_daily` server-side.
  /// [alternativesPerDay] (0-3) is how many alternatives to pick alongside
  /// the primary option — the call fails with a 422
  /// `INSUFFICIENT_OUTFIT_DATA` `ApiException` if fewer than
  /// `1 + alternativesPerDay` outfits suit the day.
  Future<List<Outfit>> generate({
    required DateTime date,
    String? occasion,
    int alternativesPerDay = 0,
  }) async {
    debugLog('--- generate: date=${DateFormat('yyyy-MM-dd').format(date)} ---');
    final uri = Uri.parse('$_baseUrl/generate');

    final body = {
      'date': DateFormat('yyyy-MM-dd').format(date),
      'occasion': ?occasion,
      'alternatives_per_day': alternativesPerDay,
    };

    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 30)),
    );

    final data = decodeMap(res, op: 'generate')['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('generate: response missing data object');
    }
    return _parseOutfits(data, op: 'generate');
  }
}
