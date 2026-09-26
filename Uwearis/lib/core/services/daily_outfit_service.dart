import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../data/daily_outfit_plan.dart';
import '../../data/outfit.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// Client for the `/daily_outfits` API — a day's shared `type: "daily"`
/// OutfitGroup, generated on its own schedule by the backend's own cron
/// (`auto_generate`, internal — not called from here) but also generable
/// on demand via [generate] (e.g. an established user who just finished
/// building out their closet, unlocking the feature for the first time —
/// see `HomePage`'s "Unlock Daily Outfits" card). [getDailyOutfit] stays
/// the source of truth for what's actually been tried on; [generate] and
/// [generateOptionOutfit] only return a snapshot of the call that just
/// happened.
class DailyOutfitService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/daily_outfits';

  /// `decodeMap` + the `data` key, asserting it's a JSON object — same
  /// shape every non-void endpoint here returns (mirrors
  /// `TripService._dataObject`).
  Map<String, dynamic> _dataObject(http.Response res, {required String op}) {
    final data = decodeMap(res, op: op)['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('$op: response missing data object');
    }
    return data;
  }

  /// Fetches [targetDate]'s outfits (`yyyy-MM-dd`). Returns null if no plan
  /// exists yet for that date.
  Future<List<Outfit>?> getDailyOutfit(String targetDate) async {
    debugLog('--- getDailyOutfit: $targetDate ---');
    final uri = Uri.parse('$_baseUrl/$targetDate');
    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );
    final envelope = decodeMap(res, op: 'getDailyOutfit');
    final data = envelope['data'];
    if (data == null) {
      debugLog('getDailyOutfit: $targetDate -> data is null (no plan yet)');
      return null;
    }
    if (data is! Map<String, dynamic>) {
      throw Exception('getDailyOutfit: invalid response');
    }
    final outfits = data['outfits'];
    if (outfits is! List) {
      throw Exception('getDailyOutfit: response missing outfits list');
    }
    final List<Outfit> result;
    try {
      result = outfits
          .whereType<Map<String, dynamic>>()
          .map(Outfit.fromJson)
          .toList();
    } catch (e) {
      debugLog('getDailyOutfit: $targetDate -> failed to parse outfits: $e');
      rethrow;
    }
    debugLog(
      'getDailyOutfit: $targetDate -> ${outfits.length} raw, '
      '${result.length} parsed',
    );
    return result;
  }

  /// Generates (or, for a date that already has one, entirely overwrites)
  /// [date]'s outfit plan — an AI text-only call (no try-on render yet),
  /// so this alone never produces an image; [generateOptionOutfit] renders
  /// a specific returned option afterward. Overwriting an existing date
  /// clears that date's old option/item rows but leaves its shared
  /// `OutfitGroup` (if any outfit was ever tried on for it) untouched —
  /// [DailyOutfitPlan.groupId] on the response reflects that same
  /// unaffected group, not a fresh one.
  ///
  /// [occasion] left null lets the backend infer one from the user's
  /// weekly schedule, falling back to [defaultOccasion] only if that
  /// inference also comes up empty. [alternativesPerDay] (0-3) is how many
  /// alternatives to generate alongside the primary option.
  Future<DailyOutfitPlan> generate({
    required DateTime date,
    String? timezone,
    String? occasion,
    String defaultOccasion = 'casual_daily',
    double? temperatureC,
    String? style,
    int alternativesPerDay = 0,
  }) async {
    debugLog('--- generate: date=${DateFormat('yyyy-MM-dd').format(date)} ---');
    final uri = Uri.parse('$_baseUrl/generate');

    final body = {
      'date': DateFormat('yyyy-MM-dd').format(date),
      'timezone': ?timezone,
      'occasion': ?occasion,
      'default_occasion': defaultOccasion,
      'temperature_c': ?temperatureC,
      'style': ?style,
      'alternatives_per_day': alternativesPerDay,
    };

    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token), body: jsonEncode(body))
          // AI text generation (occasion inference + outfit selection),
          // no image render yet — same ceiling as generateTripPlan's
          // equivalent multi-day call.
          .timeout(const Duration(seconds: 90)),
    );

    return DailyOutfitPlan.fromJson(_dataObject(res, op: 'generate'));
  }

  /// Synchronously renders [optionId] (one of the options a prior
  /// [generate] call put on that date) into a try-on image for the *first*
  /// time — background is chosen server-side. The first option tried on
  /// for a given date creates that date's shared `OutfitGroup`; every
  /// other option tried on that same date (whether a different
  /// alternative or this same one again) joins that same group instead of
  /// starting a new one. Only valid while [optionId]'s `outfit_id` is
  /// still `null` — the backend rejects a second call for an
  /// already-rendered option (`409 OPTION_ALREADY_RENDERED`) rather than
  /// re-rendering it; there's no daily-outfit `regenerate` counterpart to
  /// `TripService.regenerateOptionOutfit` yet. `result_image_url` is a
  /// 15-minute signed URL — re-fetch via [getDailyOutfit] rather than
  /// caching it past that.
  Future<DailyOutfitOption> generateOptionOutfit(int optionId) async {
    debugLog('--- generateOptionOutfit optionId=$optionId ---');
    final uri = Uri.parse('$_baseUrl/options/$optionId/outfit');

    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token))
          // AI call (Gemini) — generous ceiling, just bounds a wedged
          // request; same as every other try-on render in the app.
          .timeout(const Duration(seconds: 90)),
    );

    return DailyOutfitOption.fromJson(
      _dataObject(res, op: 'generateOptionOutfit'),
    );
  }

  /// Deletes [targetDate]'s plan (`yyyy-MM-dd`) — if that date already has
  /// a shared `OutfitGroup` from a prior try-on, the whole group and every
  /// one of its rendered outfits/images goes with it, not just the plan
  /// rows. 404 (nothing to delete) is treated as success, same as every
  /// other idempotent delete in the app.
  Future<void> deleteDailyOutfit(String targetDate) async {
    debugLog('--- deleteDailyOutfit: $targetDate ---');
    await deleteIdempotent(
      Uri.parse('$_baseUrl/$targetDate'),
      op: 'deleteDailyOutfit',
    );
  }
}
