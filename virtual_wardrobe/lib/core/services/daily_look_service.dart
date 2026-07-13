import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/garment.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

class DailyLookService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/daily_looks';

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

  Future<int?> getLook(String day) async {
    final data = await _fetchDayData(day, 'getLook');
    final jobId = data?['job_id'] as int?;
    debugLog('--- getLook job_id: $jobId ---');
    return jobId;
  }

  /// Generates a look plan for any single date (not limited to a rolling
  /// window). Always replaces any existing options for that date.
  Future<Map<String, dynamic>> generateDailyLook({
    required String date,
    String? timezone,
    String? occasion,
    String? defaultOccasion,
    num? temperatureC,
    String? style,
    int? alternativesPerDay,
  }) async {
    debugLog('--- generateDailyLook: $date ---');
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

    final envelope = decodeMap(res, op: 'generateDailyLook');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('generateDailyLook: response missing data');
    }
    return data;
  }

  /// Fetches the existing look plan for [targetDate]. Returns null data if
  /// none exists.
  Future<Map<String, dynamic>?> getDailyLook(String targetDate) async {
    debugLog('--- getDailyLook: $targetDate ---');
    final uri = Uri.parse('$_baseUrl/$targetDate');
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'getDailyLook');
    return envelope['data'] as Map<String, dynamic>?;
  }

  Future<List<Map<String, dynamic>>> listDailyLooks({
    String? startDate,
    String? endDate,
  }) async {
    debugLog('--- listDailyLooks: $startDate - $endDate ---');
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      },
    );
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'listDailyLooks');
    final data = envelope['data'];
    if (data is! List) {
      throw Exception('listDailyLooks: response missing list data');
    }
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> deleteDailyLook(String targetDate) async {
    debugLog('--- deleteDailyLook: $targetDate ---');
    final uri = Uri.parse('$_baseUrl/$targetDate');
    final res = await withAuth(
      (token) => http.delete(uri, headers: authHeaders(token)),
    );

    if (res.statusCode != 200) {
      throw Exception('deleteDailyLook failed: ${res.body}');
    }
  }

  Future<void> saveJobId(String day, int jobId) async {
    debugLog('--- saveJobId ---');
    final id = await getId(day);
    if (id == null) {
      throw Exception('saveJobId: could not find plan ID for day $day');
    }
    debugLog('--- saveJobId id: $id');
    debugLog('--- saveJobId jobId: $jobId');

    final uri = Uri.parse('$_baseUrl/options/$id/job');
    final body = {"job_id": jobId};

    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: {...authHeaders(token), 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('saveJobId failed: ${res.body}');
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
