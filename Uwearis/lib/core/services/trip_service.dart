import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/garment.dart';
import '../../data/packing_analysis.dart';
import '../../data/trip.dart';
import '../../data/trip_plan.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

class TripService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/trip_plans';

  /// `decodeMap` + `data`, asserting it's a JSON object.
  Map<String, dynamic> _dataObject(http.Response res, {required String op}) {
    final data = decodeMap(res, op: op)['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('$op: response missing data object');
    }
    return data;
  }

  /// [days] is optional (the backend derives one day per date in [legs]) and
  /// only accepts `date`/`activity`; temperature is always filled in
  /// server-side. [activities] is a creation-time default for days without
  /// their own `activity` and is not returned by any GET.
  Future<int> createTrip({
    required String name,
    required List<TripLeg> legs,
    required List<String> activities,
    List<Map<String, dynamic>>? days,
  }) async {
    debugLog('--- createTrip ---');
    final uri = Uri.parse(_baseUrl);

    final body = {
      "name": name,
      "legs": legs.map((l) => l.toJson()).toList(),
      "activity": activities,
      "days": ?days,
    };

    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token), body: jsonEncode(body))
          // Server-side per-day weather lookups take longer than 15s.
          .timeout(const Duration(seconds: 45)),
    );

    final envelope = decodeMap(res, op: 'createTrip');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('createTrip: response missing data object');
    }
    final id = (data['id'] as num?)?.toInt();
    if (id == null) throw Exception('createTrip: missing id in response');
    return id;
  }

  /// [days] keeps existing dates' plans and outfits; a date dropped from
  /// [legs]' span is deleted with its plan/outfits, a new date comes back
  /// empty. Per day, omitting `activity` keeps it and omitting temperature
  /// makes the backend refetch it. There is no trip-level activity field.
  Future<void> updateTrip(
    int tripId, {
    String? name,
    List<TripLeg>? legs,
    List<Map<String, dynamic>>? days,
  }) async {
    debugLog('--- updateTrip id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId');

    final body = <String, dynamic>{
      'name': ?name,
      if (legs != null) 'legs': legs.map((l) => l.toJson()).toList(),
      'days': ?days,
    };

    final res = await withAuth(
      (token) => http
          .patch(uri, headers: authHeaders(token), body: jsonEncode(body))
          // Re-resolves weather server-side, like createTrip.
          .timeout(const Duration(seconds: 45)),
    );

    decodeMap(res, op: 'updateTrip');
  }

  Future<List<Trip>> getTrips() async {
    debugLog('--- getTrips ---');
    final uri = Uri.parse(_baseUrl);

    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
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

  /// Each day's rendered outfits only (`days[].outfits[]`); an unrendered
  /// planned day looks like a day with no plan. Use [getTripPlan] for options.
  Future<Map<String, dynamic>> getTrip(int tripId) async {
    debugLog('--- getTrip id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId');

    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );

    final data = _dataObject(res, op: 'getTrip');
    return data;
  }

  /// Every day's `options[]`, including unrendered ones, plus the rendered
  /// `outfit_id`/`result_image_url` (null if none).
  Future<TripPlan> getTripPlan(int tripId) async {
    debugLog('--- getTripPlan id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/plan');

    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );

    return TripPlan.fromPlanResponse(_dataObject(res, op: 'getTripPlan'));
  }

  /// AI per-day options (not rendered). [days] limits it to existing dates
  /// (`TRIP_TARGET_DATES_NOT_FOUND` otherwise) and leaves other days as-is;
  /// omitting it regenerates every day, deleting rendered outfit groups.
  Future<TripPlan> generateTripPlan(
    int tripId, {
    List<Map<String, dynamic>>? days,
    int? alternativesPerDay,
  }) async {
    debugLog('--- generateTripPlan id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/generate');

    final body = <String, dynamic>{
      'days': ?days,
      'alternatives_per_day': ?alternativesPerDay,
    };

    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token), body: jsonEncode(body))
          // AI generation — generous ceiling.
          .timeout(const Duration(seconds: 90)),
    );

    return TripPlan.fromPlanResponse(_dataObject(res, op: 'generateTripPlan'));
  }

  Future<void> addSuitcaseItem(int tripId, {required int garmentId}) async {
    debugLog('--- addSuitcaseItem tripId=$tripId garmentId=$garmentId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/suitcase-items');

    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'garment_id': garmentId}),
          )
          .timeout(const Duration(seconds: 15)),
    );

    decodeMap(res, op: 'addSuitcaseItem');
  }

  /// Returns the options that still reference [garmentId], for an
  /// informational warning; they aren't changed.
  Future<List<TripAffectedOption>> removeSuitcaseItem(
    int tripId, {
    required int garmentId,
  }) async {
    debugLog('--- removeSuitcaseItem tripId=$tripId garmentId=$garmentId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/suitcase-items/$garmentId');

    final res = await withAuth(
      (token) => http
          .delete(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
    );

    final data = _dataObject(res, op: 'removeSuitcaseItem');
    final affected = (data['affected_options'] as List?) ?? const [];
    return affected
        .whereType<Map<String, dynamic>>()
        .map(TripAffectedOption.fromJson)
        .toList();
  }

  Future<void> deleteTrip(int tripId) async {
    debugLog('--- deleteTrip id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId');

    final res = await withAuth(
      (token) => http
          .delete(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
    );

    decodeMap(res, op: 'deleteTrip');
  }

  /// Re-runs the AI packing analysis; [getTripSuggestion] reads the last one.
  Future<PackingAnalysis> analyzeTrip(int tripId) async {
    debugLog('--- analyzeTrip id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/packing-analysis');

    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token))
          // AI call — generous ceiling.
          .timeout(const Duration(seconds: 90)),
    );

    return PackingAnalysis.fromJson(_dataObject(res, op: 'analyzeTrip'));
  }

  Future<PackingAnalysis> getTripSuggestion(int tripId) async {
    debugLog('--- getTripSuggestion id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/packing-analysis');

    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );

    return PackingAnalysis.fromJson(_dataObject(res, op: 'getTripSuggestion'));
  }

  /// First render of [optionId] (background = the day's leg location). An
  /// already-rendered option gets `409 OPTION_ALREADY_RENDERED`; use
  /// [regenerateOptionOutfit]. All renders of a day share one `OutfitGroup`.
  /// `result_image_url` is a short-lived signed URL.
  Future<TripOptionRender> generateOptionOutfit(
    int tripId, {
    required int optionId,
  }) async {
    debugLog('--- generateOptionOutfit tripId=$tripId optionId=$optionId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/options/$optionId/outfit');

    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token))
          // AI call — generous ceiling.
          .timeout(const Duration(seconds: 90)),
    );

    return TripOptionRender.fromJson(
      _dataObject(res, op: 'generateOptionOutfit'),
    );
  }

  /// Re-renders in place (same `outfit_id`); [backgroundId] defaults to the
  /// existing scene. A never-rendered option gets `400 OPTION_NOT_RENDERED`.
  Future<TripOptionRender> regenerateOptionOutfit(
    int tripId, {
    required int optionId,
    int? backgroundId,
  }) async {
    debugLog(
      '--- regenerateOptionOutfit tripId=$tripId optionId=$optionId ---',
    );
    final uri = Uri.parse(
      '$_baseUrl/$tripId/options/$optionId/outfit/regenerate',
    );

    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'background_id': ?backgroundId}),
          )
          // AI call — generous ceiling.
          .timeout(const Duration(seconds: 90)),
    );

    return TripOptionRender.fromJson(
      _dataObject(res, op: 'regenerateOptionOutfit'),
    );
  }

  /// Replaces an option's garments (no AI) and clears its rendered outfit.
  /// Returns the new garments from the response's `items[]`.
  Future<List<Garment>> updateOptionItems(
    int tripId, {
    required int optionId,
    required List<int> garmentIds,
  }) async {
    debugLog(
      '--- updateOptionItems tripId=$tripId optionId=$optionId garmentIds=$garmentIds ---',
    );
    final uri = Uri.parse('$_baseUrl/$tripId/options/$optionId/items');

    final res = await withAuth(
      (token) => http
          .patch(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'garment_ids': garmentIds}),
          )
          .timeout(const Duration(seconds: 15)),
    );

    final items =
        (_dataObject(res, op: 'updateOptionItems')['items'] as List?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Garment.fromTripItemJson)
        .toList();
  }
}
