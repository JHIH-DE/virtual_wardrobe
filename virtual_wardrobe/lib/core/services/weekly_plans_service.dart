import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:http/http.dart' as http;

import '../../data/garment_category.dart';
import '../config/app_config.dart';
import 'base_service.dart';

class WeeklyPlansService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/weekly_plans';

  Future<Map<String, dynamic>> createWeeklyPlan({
    required List<double?> tempsC,
    required List<String> occasions,
  }) async {
    debugPrint('--- createWeeklyPlan ---');
    final uri = Uri.parse('$_baseUrl/rolling');
    final token = await getSafeToken();
    final String defaultOccasion = 'casual_daily';
    final String defaultStyle = 'minimal';
    final effectiveToday = DateTime.now().toIso8601String().split('T')[0];
    final timezoneData = await FlutterTimezone.getLocalTimezone();
    final String effectiveTimezone = timezoneData.identifier;
    final int alternativesPerDay = 2;
    final int wardrobeVersion = 0;
    final bool forceRegenerate = false;

    final body = {
      "today": effectiveToday,
      "timezone": effectiveTimezone,
      "default_occasion": defaultOccasion,
      "style": defaultStyle,
      "temps_c": tempsC,
      "occasions": occasions,
      "alternatives_per_day": alternativesPerDay,
      "wardrobe_version": wardrobeVersion,
      "force_regenerate": forceRegenerate,
    };

    final res = await http.post(
      uri,
      headers: {
        ...authHeaders(token),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    throwIfAuthExpired(res);

    final envelope = decodeMap(res, op: 'createWeeklyPlan');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('createWeeklyPlan: response missing data object');
    }
    return data;
  }

  Future<List<Garment>> getGarments(String day) async {
    debugPrint('--- getGarments ---');
    final data = await _fetchDayData(day, 'getGarments');
    
    if (data == null || data['items'] == null) {
      throw Exception('getGarments: response missing items list');
    }

    final items = data['items'];
    if (items is! List) {
      throw Exception('getGarments: items field is not a list');
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((j) => Garment.fromJson(j))
        .toList();
  }

  Future<int?> getId(String day) async {
    debugPrint('--- getId ---');
    final data = await _fetchDayData(day, 'getId');
    return data?['id'] as int?;
  }

  Future<int?> getLook(String day) async {
    debugPrint('--- getLook ---');
    final data = await _fetchDayData(day, 'getLook');
    return data?['job_id'] as int?;
  }

  Future<void> saveJobId(String day, int jobId) async {
    debugPrint('--- saveJobId ---');
    final id = await getId(day);
    if (id == null) {
      throw Exception('saveJobId: could not find plan ID for day $day');
    }
    debugPrint('--- saveJobId id: $id');
    debugPrint('--- saveJobId jobId: $jobId');

    final uri = Uri.parse('$_baseUrl/options/$id/job');
    final token = await getSafeToken();

    final body = {
      "job_id": jobId,
    };

    final res = await http.patch(
      uri,
      headers: {
        ...authHeaders(token),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    throwIfAuthExpired(res);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('saveJobId failed: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> refreshWeeklyPlans({
    required String day,
    required double temperatureC,
    required String occasion,
  }) async {
    debugPrint('--- refreshWeeklyPlans ---');
    final uri = Uri.parse('$_baseUrl/day/refresh');
    final token = await getSafeToken();
    final effectiveTimezone = await FlutterTimezone.getLocalTimezone();
    final String defaultOccasion = 'casual_daily';
    final String style = 'minimal';
    final int alternativesPerDay = 2;
    final int wardrobeVersion = 0;
    final bool clearFavorites = true;

    final body = {
      "day": day,
      "timezone": effectiveTimezone,
      "temperature_c": temperatureC,
      "occasion": occasion,
      "style": style,
      "default_occasion": defaultOccasion,
      "alternatives_per_day": alternativesPerDay,
      "wardrobe_version": wardrobeVersion,
      "clear_favorites": clearFavorites,
    };

    final res = await http.post(
      uri,
      headers: {
        ...authHeaders(token),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    throwIfAuthExpired(res);

    final envelope = decodeMap(res, op: 'refreshWeeklyPlans');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('refreshWeeklyPlans: response missing data object');
    }
    return data;
  }

  Future<Map<String, dynamic>?> _fetchDayData(String day, String operation) async {
    final uri = Uri.parse('$_baseUrl/day');
    final token = await getSafeToken();

    final res = await http.get(
      uri.replace(queryParameters: {'day': day}),
      headers: authHeaders(token),
    );
    throwIfAuthExpired(res);

    final envelope = decodeMap(res, op: operation);
    //debugPrint('--- _fetchDayData day: $day');
    //debugPrint('--- _fetchDayData ($operation) Response: ${jsonEncode(envelope)} ---');
    final data = envelope['data'];
    return data as Map<String, dynamic>?;
  }
}
