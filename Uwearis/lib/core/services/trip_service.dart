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

  /// `decodeMap` + the `data` key, asserting it's a JSON object — the shape
  /// every non-void trip endpoint returns.
  Map<String, dynamic> _dataObject(http.Response res, {required String op}) {
    final data = decodeMap(res, op: op)['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('$op: response missing data object');
    }
    return data;
  }

  /// [days] can be omitted entirely — the backend derives one day per date
  /// in [legs]'s span on its own. [activities] is only a creation-time
  /// default (fanned out to whichever days don't specify their own
  /// `activity`); it isn't persisted on the trip itself and won't come back
  /// from any GET. Note [days]' own `TripPlanDayCreateInput` shape only
  /// accepts `date`/`activity` — any temperature fields included here are
  /// silently ignored, since the backend always fetches/estimates that
  /// itself (forecast within 15 days, historical average otherwise).
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
          // Create fans out a per-day weather lookup (geocode + Open-Meteo
          // forecast/archive) server-side, so it runs past the 15s the quick
          // calls use.
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

  /// [days] is non-destructive for dates that still exist — it derives the
  /// full set of dates from [legs]' span same as [createTrip], but an
  /// existing date only has its `activity`/temperature touched (options,
  /// `group_id`, and any already-tried-on outfits are left alone). Only a
  /// date that drops out of [legs]' span entirely gets torn down (that
  /// day's plan and its `OutfitGroup`/rendered outfits/GCS objects are
  /// deleted with it); a date newly covered by [legs] comes back as a
  /// fresh empty day. Per day: omitting `activity` keeps its current
  /// value, omitting both temperature fields makes the backend refetch
  /// them (forecast within 15 days, historical average otherwise) rather
  /// than leaving them stale.
  ///
  /// [activities] is a known no-op against the current backend contract —
  /// `activity` moved from the trip itself down to each `TripPlanDay`
  /// (`days[].activity`), and PATCH's request body has no trip-level
  /// `activity` field left to receive this anymore. Kept only so existing
  /// callers still compile; per-day activity edits need to go through
  /// [days] instead (each entry's own `activity` key) once that's wired up
  /// on the UI side.
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
      'name': ?name,
      if (legs != null) 'legs': legs.map((l) => l.toJson()).toList(),
      'activity': ?activities,
      'days': ?days,
    };

    final res = await withAuth(
      (token) => http
          .patch(uri, headers: authHeaders(token), body: jsonEncode(body))
          // Editing legs/days re-resolves those days' weather server-side
          // (see createTrip).
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
  /// option it came from — `trip_option_id`/`order_index`/`option_type`) —
  /// days with nothing tried on yet are `{group_id: null, outfits: []}`.
  ///
  /// Has no representation at all for an AI-suggested option nobody's tried
  /// on yet — a day whose plan was generated but never rendered comes back
  /// exactly like a day with no plan. [getTripPlan] is the one that can see
  /// those; use this instead only when all that's needed is what's already
  /// been rendered (e.g. a read-only day-plan summary).
  Future<Map<String, dynamic>> getTrip(int tripId) async {
    debugLog('--- getTrip id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId');

    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
    );

    final data = _dataObject(res, op: 'getTrip');
    return data;
  }

  /// Full AI plan content, unlike [getTrip] — every day's `options[]`
  /// (`reasoning`/`display_name`/`items`), including ones nobody's tried on
  /// yet, plus whichever option is currently rendered for that day
  /// (`outfit_id`/`result_image_url`, `null` if none). This is what
  /// survives leaving and reopening the trip: [generateTripPlan]'s own
  /// response is the only other place this content appears, and that's
  /// only for the instant right after generating — refetch this instead of
  /// trying to keep that response around across navigation.
  Future<TripPlan> getTripPlan(int tripId) async {
    debugLog('--- getTripPlan id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/plan');

    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
    );

    return TripPlan.fromPlanResponse(_dataObject(res, op: 'getTripPlan'));
  }

  /// Packs the suitcase into a per-day outfit plan (AI-suggested options,
  /// not yet rendered as images). [days] narrows this to specific dates —
  /// every day untouched keeps its existing options/group/rendered outfits
  /// exactly as-is, but each date in [days] must already exist on the trip
  /// (`TRIP_TARGET_DATES_NOT_FOUND` otherwise); omit it to regenerate every
  /// day instead, which does tear down each rendered day's outfit group.
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
          // AI plan generation (Gemini, per day) — generous ceiling.
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

  /// Runs the AI packing analysis (`POST .../packing-analysis`). Use
  /// [getTripSuggestion] to just re-read the last result without re-running it.
  Future<PackingAnalysis> analyzeTrip(int tripId) async {
    debugLog('--- analyzeTrip id=$tripId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/packing-analysis');

    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token))
          // AI call (Gemini) — generous ceiling, just bounds a wedged request.
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
    );

    return PackingAnalysis.fromJson(_dataObject(res, op: 'getTripSuggestion'));
  }

  /// Synchronously renders [optionId] (one of the options a prior
  /// [generateTripPlan] call put on that day) into a try-on image for the
  /// *first* time — background is whichever location that day's `TripLeg`
  /// covers, not a user-picked scene. The first option tried on for a
  /// given day creates that day's shared `OutfitGroup`; every other option
  /// tried on that same day (whether picking a different alternative or
  /// this same one) joins that same group instead of starting a new one.
  /// Only valid while [optionId]'s `outfit_id` is still `null` — call this
  /// again on an option that's already rendered and the backend rejects it
  /// with `409 OPTION_ALREADY_RENDERED` rather than re-rendering; use
  /// [regenerateOptionOutfit] for that instead. `result_image_url` is a GCS
  /// signed URL good for 15 minutes; re-fetch via [getTrip]/[getTripPlan]
  /// rather than caching it past that.
  Future<TripOptionRender> generateOptionOutfit(
    int tripId, {
    required int optionId,
  }) async {
    debugLog('--- generateOptionOutfit tripId=$tripId optionId=$optionId ---');
    final uri = Uri.parse('$_baseUrl/$tripId/options/$optionId/outfit');

    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token))
          // AI call (Gemini) — generous ceiling, just bounds a wedged request.
          .timeout(const Duration(seconds: 90)),
    );

    return TripOptionRender.fromJson(
      _dataObject(res, op: 'generateOptionOutfit'),
    );
  }

  /// Re-renders [optionId]'s *already-rendered* outfit in place — same
  /// garments, same `outfit_id` (never a new one), just a fresh render;
  /// only [backgroundId] (from `GET /api/v1/backgrounds`) can change what
  /// comes out, defaulting to whatever scene the existing render already
  /// used. Only valid once [optionId] actually has an `outfit_id` — call
  /// this on an option that's never been rendered and the backend rejects
  /// it with `400 OPTION_NOT_RENDERED`; use [generateOptionOutfit] for
  /// that instead. Same 15-minute signed-URL caveat as
  /// [generateOptionOutfit] applies to the returned `result_image_url`.
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
          // AI render — generous ceiling, just bounds a wedged request.
          .timeout(const Duration(seconds: 90)),
    );

    return TripOptionRender.fromJson(
      _dataObject(res, op: 'regenerateOptionOutfit'),
    );
  }

  /// Manually replaces the garments in a trip outfit option (e.g. the user
  /// swapping out what Uwearis picked for a given day) — does not call AI
  /// again. Clears that option's already-tried-on outfit, if any (see
  /// [generateOptionOutfit] to try it on again with the new garments).
  /// Returns the option's garments *after* the swap, parsed from the
  /// response's embedded `items[]` (each carries its own image/name/
  /// category, so no closet lookup).
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
