import 'dart:async';
import 'dart:convert';

import '../utils/debug_log.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'base_service.dart';

class TripPlanService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/trip_plans';

  Future<Map<String, dynamic>> createTripPlan({
    required String name,
    required String location,
    required String startDate,
    required String endDate,
    required String style,
    required String defaultOccasion,
    required List<Map<String, dynamic>> days,
  }) async {
    debugLog('--- createTripPlan ---');
    final uri = Uri.parse(_baseUrl);
    final timezone = await FlutterTimezone.getLocalTimezone();

    final body = {
      "name": name,
      "location": location,
      "start_date": startDate,
      "end_date": endDate,
      "timezone": timezone,
      "default_occasion": defaultOccasion,
      "style": style,
      "days": days,
    };

    final res = await withAuth((token) => http.post(
      uri,
      headers: {
        ...authHeaders(token),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    ));

    final envelope = decodeMap(res, op: 'createTripPlan');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('createTripPlan: response missing data object');
    }
    return data;
  }
}
