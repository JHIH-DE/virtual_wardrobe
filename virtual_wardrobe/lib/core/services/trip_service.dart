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
    required List<String> activities,
    required List<Map<String, dynamic>> days,
  }) async {
    debugLog('--- createTrip ---');
    final uri = Uri.parse(_baseUrl);

    final body = {
      "name": name,
      "legs": legs.map((l) => l.toJson()).toList(),
      "activity": activities,
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

  Future<void> updateTrip(
    int tripId, {
    String? name,
    List<TripLeg>? legs,
    List<String>? activities,
    List<Map<String, dynamic>>? days,
  }) async {
    debugLog('--- updateTrip id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId');

    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (legs != null) 'legs': legs.map((l) => l.toJson()).toList(),
      if (activities != null) 'activity': activities,
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

  /// Full trip structure with each day's already-tried-on outfits
  /// (`days[].outfits[]`, same shape as `/api/v1/outfit`'s `Outfit` plus the
  /// option it came from) — days with nothing tried on yet are
  /// `{group_id: null, outfits: []}`. Does not include AI-suggested option
  /// content (reasoning, which garments an untried option picked) — that
  /// only ever appears in [generateTripPlan]/[autoGenerateTripPlan]'s
  /// response, immediately after generating.
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

  /// Packs the suitcase into a per-day outfit plan (AI-suggested options,
  /// not yet rendered as images). Rebuilds every day's `TripPlanDay` from
  /// scratch — any day that already had a try-on group loses it, GCS
  /// objects included.
  Future<Map<String, dynamic>> generateTripPlan(
    int tripId, {
    List<Map<String, dynamic>>? days,
  }) async {
    debugLog('--- generateTripPlan id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/generate');

    final body = <String, dynamic>{if (days != null) 'days': days};

    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: {...authHeaders(token), 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );

    final envelope = decodeMap(res, op: 'generateTripPlan');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('generateTripPlan: response missing data object');
    }
    return data;
  }

  /// Same as [generateTripPlan], but also synchronously renders every
  /// option on every day (not just the one the user picks via
  /// [generateOptionOutfit]) — one call covers the whole trip, at the cost
  /// of a much longer request (measured over 2 minutes for a multi-day
  /// trip; scale timeouts/loading UI accordingly).
  Future<Map<String, dynamic>> autoGenerateTripPlan(
    int tripId, {
    List<Map<String, dynamic>>? days,
  }) async {
    debugLog('--- autoGenerateTripPlan id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/auto_generate');

    final body = <String, dynamic>{if (days != null) 'days': days};

    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: {...authHeaders(token), 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );

    final envelope = decodeMap(res, op: 'autoGenerateTripPlan');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('autoGenerateTripPlan: response missing data object');
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

  /// Synchronously renders [optionId] (one of the options a prior
  /// [generateTripPlan] call put on that day) into a try-on image. The
  /// first option tried on for a given day creates that day's shared
  /// `OutfitGroup`; every other option tried on that same day (whether
  /// picking a different alternative or redoing the same one) joins that
  /// same group instead of starting a new one.
  Future<Map<String, dynamic>> generateOptionOutfit(
    int tripId, {
    required int optionId,
  }) async {
    debugLog('--- generateOptionOutfit tripId=$tripId optionId=$optionId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/options/$optionId/outfit');

    final res = await withAuth(
      (token) => http.post(uri, headers: authHeaders(token)),
    );

    final envelope = decodeMap(res, op: 'generateOptionOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('generateOptionOutfit: response missing data object');
    }
    return data;
  }

  /// Manually replaces the garments in a trip outfit option (e.g. the user
  /// swapping out what Uwearis picked for a given day) — does not call AI
  /// again. Clears that option's already-tried-on outfit, if any (see
  /// [generateOptionOutfit] to try it on again with the new garments).
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
