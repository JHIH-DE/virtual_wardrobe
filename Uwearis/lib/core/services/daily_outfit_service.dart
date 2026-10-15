import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../data/outfit.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// `/daily_outfits`: a day's options point at the user's own `general`
/// outfits, picked server-side by rules (no AI render, no quota). Only
/// [generate] creates a plan; nothing does it in the background.
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

  /// The day's outfits in option order.
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

  /// Picks (or overwrites) [date]'s plan; randomized, so a repeat call
  /// usually differs. Overwriting leaves the outfits themselves untouched.
  ///
  /// Null [occasion] reuses the stored one (server default `casual_daily`).
  /// [alternativesPerDay] is 0-3; fewer than `1 + alternativesPerDay`
  /// suitable outfits is a 422 `INSUFFICIENT_OUTFIT_DATA`.
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
