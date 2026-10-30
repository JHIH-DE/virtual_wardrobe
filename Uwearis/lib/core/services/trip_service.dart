import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/garment.dart';
import '../../data/packing_analysis.dart';
import '../../data/trip.dart';
import '../../data/trip_outfit.dart';
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

  /// Packs [garmentIds] in one transaction (already-packed ones are
  /// skipped) and returns the resulting suitcase.
  Future<List<Garment>> addSuitcaseItems(
    int tripId, {
    required List<int> garmentIds,
  }) async {
    debugLog('--- addSuitcaseItems: tripId=$tripId garmentIds=$garmentIds ---');
    final uri = Uri.parse('$_baseUrl/$tripId/suitcase-items');

    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'garment_ids': garmentIds}),
          )
          .timeout(const Duration(seconds: 15)),
    );

    final items =
        (_dataObject(res, op: 'addSuitcaseItems')['suitcase_items'] as List?) ??
        const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(Garment.fromTripItemJson)
        .toList();
  }

  /// Trip outfits using [garmentId] are kept and marked missing.
  Future<void> removeSuitcaseItem(int tripId, {required int garmentId}) async {
    debugLog('--- removeSuitcaseItem tripId=$tripId garmentId=$garmentId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/suitcase-items/$garmentId');

    final res = await withAuth(
      (token) => http
          .delete(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
    );

    decodeMap(res, op: 'removeSuitcaseItem');
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

  // ---- Trip Outfit Collection: every call returns the whole collection ----

  Future<TripOutfitCollection> getTripOutfits(int tripId) async {
    debugLog('--- getTripOutfits: id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/outfits');

    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );

    return TripOutfitCollection.fromJson(
      _dataObject(res, op: 'getTripOutfits'),
    );
  }

  /// Packs [outfitId]'s missing garments and adds the outfit, in one
  /// transaction. `409 TRIP_OUTFIT_ALREADY_ADDED` for the same version,
  /// `409 TRIP_OUTFIT_DUPLICATE` for the same garments.
  Future<TripOutfitCollection> addTripOutfitFromSaved(
    int tripId, {
    required int outfitId,
  }) async {
    debugLog(
      '--- addTripOutfitFromSaved: tripId=$tripId outfitId=$outfitId ---',
    );
    final uri = Uri.parse('$_baseUrl/$tripId/outfits/from-saved');

    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'outfit_id': outfitId}),
          )
          .timeout(const Duration(seconds: 15)),
    );

    return TripOutfitCollection.fromJson(
      _dataObject(res, op: 'addTripOutfitFromSaved'),
    );
  }

  /// [garmentIds] must all be packed and form a complete outfit.
  Future<TripOutfitCollection> createTripOutfit(
    int tripId, {
    required List<int> garmentIds,
  }) async {
    debugLog('--- createTripOutfit: tripId=$tripId garmentIds=$garmentIds ---');
    final uri = Uri.parse('$_baseUrl/$tripId/outfits');

    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'garment_ids': garmentIds}),
          )
          .timeout(const Duration(seconds: 15)),
    );

    return TripOutfitCollection.fromJson(
      _dataObject(res, op: 'createTripOutfit'),
    );
  }

  /// Changing [garmentIds] drops this trip outfit's own render (the saved
  /// outfit it came from is never touched).
  Future<TripOutfitCollection> updateTripOutfit(
    int tripId, {
    required int tripOutfitId,
    List<int>? garmentIds,
    bool? isPinned,
  }) async {
    debugLog(
      '--- updateTripOutfit: tripId=$tripId tripOutfitId=$tripOutfitId ---',
    );
    final uri = Uri.parse('$_baseUrl/$tripId/outfits/$tripOutfitId');

    final res = await withAuth(
      (token) => http
          .patch(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({
              'garment_ids': ?garmentIds,
              'is_pinned': ?isPinned,
            }),
          )
          .timeout(const Duration(seconds: 15)),
    );

    return TripOutfitCollection.fromJson(
      _dataObject(res, op: 'updateTripOutfit'),
    );
  }

  /// Leaves the suitcase and the source saved outfit as they are.
  Future<TripOutfitCollection> removeTripOutfit(
    int tripId, {
    required int tripOutfitId,
  }) async {
    debugLog(
      '--- removeTripOutfit: tripId=$tripId tripOutfitId=$tripOutfitId ---',
    );
    final uri = Uri.parse('$_baseUrl/$tripId/outfits/$tripOutfitId');

    final res = await withAuth(
      (token) => http
          .delete(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
    );

    return TripOutfitCollection.fromJson(
      _dataObject(res, op: 'removeTripOutfit'),
    );
  }

  /// AI suggestions from the suitcase (no try-on). `409
  /// TRIP_OUTFIT_GENERATION_IN_PROGRESS` while another run is going.
  Future<TripOutfitGenerateResult> generateTripOutfits(
    int tripId, {
    required TripOutfitGenerateMode mode,
  }) async {
    debugLog(
      '--- generateTripOutfits: tripId=$tripId mode=${mode.apiValue} ---',
    );
    final uri = Uri.parse('$_baseUrl/$tripId/outfits/generate');

    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'mode': mode.apiValue}),
          )
          // AI generation — generous ceiling.
          .timeout(const Duration(seconds: 90)),
    );

    return TripOutfitGenerateResult.fromJson(
      _dataObject(res, op: 'generateTripOutfits'),
    );
  }

  /// First render or in-place re-render of [tripOutfitId]'s try-on.
  Future<TripOutfitCollection> tryOnTripOutfit(
    int tripId, {
    required int tripOutfitId,
  }) async {
    debugLog(
      '--- tryOnTripOutfit: tripId=$tripId tripOutfitId=$tripOutfitId ---',
    );
    final uri = Uri.parse('$_baseUrl/$tripId/outfits/$tripOutfitId/try-on');

    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token))
          // AI call — generous ceiling.
          .timeout(const Duration(seconds: 90)),
    );

    return TripOutfitCollection.fromJson(
      _dataObject(res, op: 'tryOnTripOutfit'),
    );
  }
}
