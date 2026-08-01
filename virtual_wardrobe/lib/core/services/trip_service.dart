import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/trip.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

class TripService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/trip_plans';

  Future<int> createTrip({
    required String name,
    required List<TripLeg> legs,
    required String purpose,
    required List<Map<String, dynamic>> days,
  }) async {
    debugLog('--- createTrip ---');
    final uri = Uri.parse(_baseUrl);

    final body = {
      "name": name,
      "legs": legs.map((l) => l.toJson()).toList(),
      "purpose": purpose,
      "days": days,
    };
    debugLog('createTrip body: ${jsonEncode(body)}');

    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: {...authHeaders(token), 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );

    final envelope = decodeMap(res, op: 'createTrip');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('createTrip: response missing data object');
    }
    final id = data['id'];
    if (id is! int) throw Exception('createTrip: missing id in response');
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

  Future<void> updateTrip(
    int tripId, {
    String? name,
    List<TripLeg>? legs,
    String? purpose,
    String? defaultOccasion,
    String? style,
    List<Map<String, dynamic>>? days,
  }) async {
    debugLog('--- updateTrip id=$tripId ---');
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

    decodeMap(res, op: 'updateTrip');
  }

  Future<List<Trip>> getTrips() async {
    debugLog('--- getTrips ---');
    final uri = Uri.parse(_baseUrl);

    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'getTrips');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getTrips: response missing data object');
    }
    final items = data['items'];
    if (items is! List) {
      throw Exception('getTrips: response missing items array');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map((j) => Trip.fromJson(j))
        .toList();
  }

  Future<Map<String, dynamic>> getTrip(int tripId) async {
    debugLog('--- getTrip id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId');

    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'getTrip');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getTrip: response missing data object');
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

  Future<void> deleteTrip(int tripId) async {
    debugLog('--- deleteTrip id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId');

    final res = await withAuth(
      (token) => http.delete(uri, headers: authHeaders(token)),
    );

    decodeMap(res, op: 'deleteTrip');
  }

  Future<Map<String, dynamic>> analyzeTrip(int tripId) async {
    debugLog('--- analyzeTrip id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/packing-analysis');

    final res = await withAuth(
      (token) => http.post(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'analyzeTrip');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('analyzeTrip: response missing data object');
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

  /// Manually replaces the garments in a trip outfit option (e.g. the user
  /// swapping out what LUMI picked for a given day).
  Future<Map<String, dynamic>> updateOptionItems(
    int tripId, {
    required int optionId,
    required List<int> garmentIds,
  }) async {
    debugLog(
      '--- updateOptionItems tripId=$tripId optionId=$optionId garmentIds=$garmentIds ---',
    );
    final uri = Uri.parse('$_baseUrl/$tripId/options/$optionId/items');

    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: {...authHeaders(token), 'Content-Type': 'application/json'},
        body: jsonEncode({'garment_ids': garmentIds}),
      ),
    );

    final envelope = decodeMap(res, op: 'updateOptionItems');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('updateOptionItems: response missing data object');
    }
    return data;
  }
}
