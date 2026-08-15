import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/garment.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

class DailyOutfitService with BaseService {
  // Backend route is still `/daily_outfits/` — not renamed here since that's
  // a live API contract, not just app-side wording.
  static final String _baseUrl = '${AppConfig.fullApiUrl}/daily_outfits';

  Future<List<Garment>> getGarments(String day) async {
    final data = await _fetchDayData(day, 'getGarments');

    if (data == null || data['items'] == null) {
      throw Exception('getGarments: response missing items list');
    }

    final items = data['items'];
    if (items is! List) {
      throw Exception('getGarments: items field is not a list');
    } else {
      final ids = items
          .whereType<Map<String, dynamic>>()
          .map((j) => j['garment_id'])
          .toList();
      debugLog('--- getGarments ids: $ids ---');
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((j) => Garment.fromJson(j))
        .toList();
  }

  Future<int?> getId(String day) async {
    final data = await _fetchDayData(day, 'getId');
    final id = data?['id'] as int?;
    debugLog('--- getId id: $id ---');
    return id;
  }

  Future<int?> getOutfit(String day) async {
    final data = await _fetchDayData(day, 'getOutfit');
    final outfitId = data?['outfit_id'] as int?;
    debugLog('--- getOutfit outfit_id: $outfitId ---');
    return outfitId;
  }

  /// Generates an outfit plan for any single date (not limited to a rolling
  /// window). Always replaces any existing options for that date. Returns
  /// the primary option's id (lowest `order_index`).
  Future<int> generateDailyOutfit({
    required String date,
    String? timezone,
    String? occasion,
    String? defaultOccasion,
    num? temperatureC,
    String? style,
    int? alternativesPerDay,
  }) async {
    debugLog('--- generateDailyOutfit: $date ---');
    final uri = Uri.parse('$_baseUrl/generate');
    final body = <String, dynamic>{
      'date': date,
      if (timezone != null) 'timezone': timezone,
      if (occasion != null) 'occasion': occasion,
      if (defaultOccasion != null) 'default_occasion': defaultOccasion,
      if (temperatureC != null) 'temperature_c': temperatureC,
      if (style != null) 'style': style,
      if (alternativesPerDay != null)
        'alternatives_per_day': alternativesPerDay,
    };

    final res = await withAuth(
      (token) =>
          http.post(uri, headers: authHeaders(token), body: jsonEncode(body)),
    );

    final envelope = decodeMap(res, op: 'generateDailyOutfit');
    final data = envelope['data'] as Map<String, dynamic>?;
    final options =
        ((data?['options'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .toList()
          ..sort(
            (a, b) => ((a['order_index'] as num?) ?? 0).compareTo(
              (b['order_index'] as num?) ?? 0,
            ),
          );
    final id = options.isEmpty ? null : options.first['id'] as int?;
    if (id == null) {
      throw Exception('generateDailyOutfit: response missing options[0].id');
    }
    return id;
  }

  /// Creates a try-on render job for one outfit option, using the garments
  /// already selected on that option (from a prior [generateDailyOutfit]
  /// call), and queues the render in the background. Returns the new job id.
  Future<int?> createTryOnForOption(int optionId) async {
    debugLog('--- createTryOnForOption: $optionId ---');
    final uri = Uri.parse('$_baseUrl/options/$optionId/tryon');
    final res = await withAuth(
      (token) => http.post(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'createTryOnForOption');
    final data = envelope['data'] as Map<String, dynamic>?;
    final outfitId = data?['outfit_id'] as int?;
    debugLog('--- createTryOnForOption outfit_id: $outfitId ---');
    return outfitId;
  }

  /// Fetches the existing outfit plan for [targetDate]. Returns null data if
  /// none exists.
  Future<Map<String, dynamic>?> getDailyOutfit(String targetDate) async {
    debugLog('--- getDailyOutfit: $targetDate ---');
    final uri = Uri.parse('$_baseUrl/$targetDate');
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    debugLog(
      '--- getDailyOutfit response (${res.statusCode}): ${res.body} ---',
    );
    if (res.statusCode == 404) return null;

    final envelope = decodeMap(res, op: 'getDailyOutfit');
    final data = envelope['data'] as Map<String, dynamic>?;
    return data;
  }

  Future<List<Map<String, dynamic>>> listDailyOutfits({
    String? startDate,
    String? endDate,
  }) async {
    debugLog('--- listDailyOutfits: $startDate - $endDate ---');
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'listDailyOutfits');
    final data = envelope['data'];
    if (data is! List) {
      throw Exception('listDailyOutfits: response missing list data');
    }
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> deleteDailyOutfit(String targetDate) async {
    debugLog('--- deleteDailyOutfit: $targetDate ---');
    final uri = Uri.parse('$_baseUrl/$targetDate');
    final res = await withAuth(
      (token) => http.delete(uri, headers: authHeaders(token)),
    );

    if (res.statusCode != 200) {
      throw Exception('deleteDailyOutfit failed: ${res.body}');
    }
  }

  Future<Map<String, dynamic>?> _fetchDayData(
    String day,
    String operation,
  ) async {
    final uri = Uri.parse('$_baseUrl/day');
    final res = await withAuth(
      (token) => http.get(
        uri.replace(queryParameters: {'day': day}),
        headers: authHeaders(token),
      ),
    );

    final envelope = decodeMap(res, op: operation);
    final data = envelope['data'];
    return data as Map<String, dynamic>?;
  }
}
