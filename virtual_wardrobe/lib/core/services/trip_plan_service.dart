import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/trip_plan.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

class TripPlanService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/trip_plans';

  Future<int> createTripPlan({
    required String name,
    required List<TripLeg> legs,
    required String purpose,
    required List<Map<String, dynamic>> days,
  }) async {
    debugLog('--- createTripPlan ---');
    final uri = Uri.parse(_baseUrl);

    final body = {
      "name": name,
      "legs": legs.map((l) => l.toJson()).toList(),
      "purpose": purpose,
      "days": days,
    };
    debugLog('createTripPlan body: ${jsonEncode(body)}');

    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: {...authHeaders(token), 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );

    final envelope = decodeMap(res, op: 'createTripPlan');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('createTripPlan: response missing data object');
    }
    final id = data['id'];
    if (id is! int) throw Exception('createTripPlan: missing id in response');
    return id;
  }

  Future<void> generateTripPlan(
    int tripId, {
    String? defaultOccasion,
    String? style,
    List<Map<String, dynamic>>? days,
    bool? minimizePacking,
    Map<String, int>? categoryLimits,
  }) async {
    debugLog('--- generateTripPlan id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/generate');

    final body = <String, dynamic>{
      if (defaultOccasion != null) 'default_occasion': defaultOccasion,
      if (style != null) 'style': style,
      if (days != null) 'days': days,
      if (minimizePacking != null) 'minimize_packing': minimizePacking,
      if (categoryLimits != null) 'category_limits': categoryLimits,
    };

    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: {...authHeaders(token), 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );

    decodeMap(res, op: 'generateTripPlan');
  }

  Future<void> updateTripPlan(
    int tripId, {
    String? name,
    List<TripLeg>? legs,
    String? purpose,
    String? defaultOccasion,
    String? style,
    List<Map<String, dynamic>>? days,
  }) async {
    debugLog('--- updateTripPlan id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId');

    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (legs != null) 'legs': legs.map((l) => l.toJson()).toList(),
      if (purpose != null) 'purpose': purpose,
      if (defaultOccasion != null) 'default_occasion': defaultOccasion,
      if (style != null) 'style': style,
      if (days != null) 'days': days,
    };

    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: {...authHeaders(token), 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );

    decodeMap(res, op: 'updateTripPlan');
  }

  Future<List<TripPlan>> getTripPlans() async {
    debugLog('--- getTripPlans ---');
    final uri = Uri.parse(_baseUrl);

    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'getTripPlans');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getTripPlans: response missing data object');
    }
    final items = data['items'];
    if (items is! List) {
      throw Exception('getTripPlans: response missing items array');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map((j) => TripPlan.fromJson(j))
        .toList();
  }

  Future<Map<String, dynamic>> getTripPlan(int tripId) async {
    debugLog('--- getTripPlan id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId');

    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'getTripPlan');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getTripPlan: response missing data object');
    }
    return data;
  }

  Future<void> addSuitcaseItem(int tripId, {required int garmentId}) async {
    debugLog('--- addSuitcaseItem tripId=$tripId garmentId=$garmentId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/suitcase-items');

    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: {...authHeaders(token), 'Content-Type': 'application/json'},
        body: jsonEncode({'garment_id': garmentId}),
      ),
    );

    decodeMap(res, op: 'addSuitcaseItem');
  }

  Future<void> removeSuitcaseItem(int tripId, {required int garmentId}) async {
    debugLog('--- removeSuitcaseItem tripId=$tripId garmentId=$garmentId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/suitcase-items/$garmentId');

    final res = await withAuth(
      (token) => http.delete(uri, headers: authHeaders(token)),
    );

    decodeMap(res, op: 'removeSuitcaseItem');
  }

  Future<void> deleteTripPlan(int tripId) async {
    debugLog('--- deleteTripPlan id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId');

    final res = await withAuth(
      (token) => http.delete(uri, headers: authHeaders(token)),
    );

    decodeMap(res, op: 'deleteTripPlan');
  }

  Future<Map<String, dynamic>> analyzeTripPlan(int tripId) async {
    debugLog('--- analyzeTripPlan id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/packing-analysis');

    final res = await withAuth(
      (token) => http.post(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'analyzeTripPlan');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('analyzeTripPlan: response missing data object');
    }
    return data;
  }

  Future<Map<String, dynamic>> getTripSuggestion(int tripId) async {
    debugLog('--- getTripSuggestion id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/packing-analysis');

    final res = await withAuth(
          (token) => http.get(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'getTripSuggestion');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getTripSuggestion: response missing data object');
    }
    return data;
  }

  Future<Map<String, dynamic>> setTryonJobToOption(
    int jobId, {
    required int optionId,
    required int tripId,
  }) async {
    debugLog(
      '--- setTryonJobToOption tripId=$tripId optionId=$optionId jobId=$jobId ---',
    );
    final uri = Uri.parse('$_baseUrl/$tripId/options/$optionId/job');

    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: {...authHeaders(token), 'Content-Type': 'application/json'},
        body: jsonEncode({'job_id': jobId}),
      ),
    );

    final envelope = decodeMap(res, op: 'setTryonJobToOption');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('setTryonJobToOption: response missing data object');
    }
    return data;
  }
}
