import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/outfit.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// Client for the OutfitGroup + Outfit API (`/api/v1/outfit`). Every outfit
/// lives inside a group (general/daily/trip) and carries its own render
/// result inline, and `generate` does creation + AI render in one
/// synchronous call. Only `type=general` has a full, actively-used path
/// today — a general-flow outfit gets its own dedicated group, so
/// [getAllOutfits] and [getOutfitsByGarments] flatten the group nesting away
/// and the rest of the app keeps treating outfits as a flat list.
class OutfitService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/outfit';

  Future<int> createGroup({String type = 'general'}) async {
    debugLog('--- createGroup: type=$type ---');
    final uri = Uri.parse(_baseUrl);
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'type': type}),
      ),
    );
    final envelope = decodeMap(res, op: 'createGroup');
    final data = envelope['data'];
    final groupId = data is Map<String, dynamic>
        ? data['group_id'] as int?
        : null;
    if (groupId == null) {
      throw Exception('createGroup: response missing group_id');
    }
    return groupId;
  }

  Future<List<Outfit>> getAllOutfits({
    String type = 'general',
    int page = 1,
    int size = 100,
    String? sort,
  }) async {
    debugLog(
      '--- getAllOutfits: type=$type page=$page size=$size sort=$sort ---',
    );
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'type': type,
        'page': '$page',
        'size': '$size',
        if (sort != null) 'sort': sort,
      },
    );
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'getAllOutfits');
    final data = envelope['data'];
    final items = data is Map<String, dynamic> ? data['items'] : null;
    if (items is! List) {
      throw Exception('getAllOutfits: response missing items list');
    }
    // One card per group, not per outfit — a group can hold multiple
    // versions (Outfit Details' "Create Another Version"), but the flat
    // list only shows one as that group's representative; every version is
    // browsable from Outfit Details' own carousel. The representative
    // still carries the group's real version count (see
    // Outfit.versionCount) for callers that need the true total, like
    // Style Taste's "N outfits analyzed" stat.
    final outfits = <Outfit>[];
    for (final group in items.whereType<Map<String, dynamic>>()) {
      final groupOutfits = group['outfits'];
      if (groupOutfits is List) {
        final parsed = groupOutfits
            .whereType<Map<String, dynamic>>()
            .map(Outfit.fromJson)
            .toList();
        if (parsed.isEmpty) continue;
        final coverOutfitId = (group['cover_outfit_id'] as num?)?.toInt();
        // Backend's own default rule when cover_outfit_id is null: the
        // group's lowest outfit_id (its earliest-created outfit).
        final representative = coverOutfitId != null
            ? parsed.firstWhere(
                (o) => o.id == coverOutfitId,
                orElse: () => parsed.reduce((a, b) => a.id < b.id ? a : b),
              )
            : parsed.reduce((a, b) => a.id < b.id ? a : b);
        outfits.add(
          representative.copyWith(
            versionCount: parsed.length,
            coverOutfitId: coverOutfitId,
            clearCoverOutfitId: coverOutfitId == null,
          ),
        );
      }
    }
    return outfits;
  }

  /// Creates a new outfit and renders it in one call (~10-15s for the AI
  /// render) — there is no separate save step. Pass [groupId] to add this
  /// as another version alongside an existing outfit (e.g. Outfit Details'
  /// "Create Another Version"); omit it to start a fresh [type] group (the
  /// normal create-outfit flow).
  Future<Outfit> generateOutfit({
    required List<int> garmentIds,
    int? groupId,
    String type = 'general',
    int? backgroundId,
    bool isFavorite = false,
  }) async {
    groupId ??= await createGroup(type: type);
    debugLog(
      '--- generateOutfit: groupId=$groupId garmentIds=$garmentIds '
      'backgroundId=$backgroundId ---',
    );
    final uri = Uri.parse('$_baseUrl/$groupId/generate');
    final payload = <String, dynamic>{
      'garment_ids': garmentIds,
      if (backgroundId != null) 'background_id': backgroundId,
      'is_favorite': isFavorite,
    };
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode(payload),
      ),
    );
    final envelope = decodeMap(res, op: 'generateOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('generateOutfit: response missing outfit data object');
    }
    return Outfit.fromJson(data);
  }

  /// Re-renders [outfitId] in place with the same garment combo — overwrites
  /// the existing image, `outfit_id`/`name`/`style`/`season`/`garment_ids`
  /// stay unchanged, no new outfit is created. Omit [backgroundId] to reuse
  /// the outfit's current background.
  Future<Outfit> regenerateOutfit(
    int groupId,
    int outfitId, {
    int? backgroundId,
  }) async {
    debugLog(
      '--- regenerateOutfit: groupId=$groupId outfitId=$outfitId '
      'backgroundId=$backgroundId ---',
    );
    final uri = Uri.parse('$_baseUrl/$groupId/$outfitId/regenerate');
    final payload = <String, dynamic>{
      if (backgroundId != null) 'background_id': backgroundId,
    };
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode(payload),
      ),
    );
    final envelope = decodeMap(res, op: 'regenerateOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('regenerateOutfit: response missing outfit data object');
    }
    return Outfit.fromJson(data);
  }

  /// Duplicates [sourceOutfitId] (any group type, must already be fully
  /// rendered) into [groupId] as a new, independent [Outfit] there — no AI
  /// re-render, the backend copies the existing image to a new GCS path.
  /// [groupId] must be a `type: general` group; omit it to create a fresh
  /// one first. The source outfit itself is untouched (this is a copy, not
  /// a move).
  Future<Outfit> copyOutfit({int? groupId, required int sourceOutfitId}) async {
    groupId ??= await createGroup(type: 'general');
    debugLog('--- copyOutfit: groupId=$groupId sourceOutfitId=$sourceOutfitId ---');
    final uri = Uri.parse('$_baseUrl/$groupId/copy');
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'source_outfit_id': sourceOutfitId}),
      ),
    );
    final envelope = decodeMap(res, op: 'copyOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('copyOutfit: response missing outfit data object');
    }
    return Outfit.fromJson(data);
  }

  Future<Outfit> getOutfit(int groupId, int outfitId) async {
    debugLog('--- getOutfit: groupId=$groupId outfitId=$outfitId ---');
    final uri = Uri.parse('$_baseUrl/$groupId/$outfitId');
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'getOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getOutfit: response missing outfit data object');
    }
    return Outfit.fromJson(data);
  }

  /// Partial update — only pass the fields that changed, the rest are left
  /// untouched server-side.
  Future<Outfit> updateOutfit(
    int groupId,
    int outfitId, {
    bool? isFavorite,
    String? name,
    List<String>? style,
    List<String>? season,
  }) async {
    debugLog('--- updateOutfit: groupId=$groupId outfitId=$outfitId ---');
    final uri = Uri.parse('$_baseUrl/$groupId/$outfitId');
    final payload = <String, dynamic>{
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (name != null) 'name': name,
      if (style != null) 'style': style,
      if (season != null) 'season': season,
    };
    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: authHeaders(token),
        body: jsonEncode(payload),
      ),
    );
    final envelope = decodeMap(res, op: 'updateOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('updateOutfit: response missing outfit data object');
    }
    return Outfit.fromJson(data);
  }

  /// Deletes a single outfit; the parent group is untouched even if this
  /// was its last outfit.
  Future<void> deleteOutfit(int groupId, int outfitId) async {
    debugLog('--- deleteOutfit: groupId=$groupId outfitId=$outfitId ---');
    final uri = Uri.parse('$_baseUrl/$groupId/$outfitId');
    final res = await withAuth(
      (token) => http.delete(uri, headers: authHeaders(token)),
    );
    decodeMap(res, op: 'deleteOutfit');
  }

  /// Every outfit inside [groupId] — used to check whether an outfit has
  /// siblings before deciding whether deleting it should take the
  /// now-empty group with it.
  Future<List<Outfit>> getGroupOutfits(int groupId) async {
    debugLog('--- getGroupOutfits: groupId=$groupId ---');
    final uri = Uri.parse('$_baseUrl/$groupId');
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'getGroupOutfits');
    final data = envelope['data'];
    final outfits = data is Map<String, dynamic> ? data['outfits'] : null;
    if (outfits is! List) {
      throw Exception('getGroupOutfits: response missing outfits list');
    }
    final coverOutfitId = data is Map<String, dynamic>
        ? (data['cover_outfit_id'] as num?)?.toInt()
        : null;
    return outfits
        .whereType<Map<String, dynamic>>()
        .map(Outfit.fromJson)
        .map(
          (o) => o.copyWith(
            coverOutfitId: coverOutfitId,
            clearCoverOutfitId: coverOutfitId == null,
          ),
        )
        .toList();
  }

  /// Sets (or, with `null`, clears) [groupId]'s cover outfit — the version
  /// shown as that group's representative in the flat Outfits list (see
  /// [getAllOutfits]). [coverOutfitId] must belong to [groupId] and already
  /// be fully rendered.
  Future<void> setGroupCover(int groupId, int? coverOutfitId) async {
    debugLog('--- setGroupCover: groupId=$groupId coverOutfitId=$coverOutfitId ---');
    final uri = Uri.parse('$_baseUrl/$groupId');
    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'cover_outfit_id': coverOutfitId}),
      ),
    );
    decodeMap(res, op: 'setGroupCover');
  }

  /// Deletes the whole group, cascading to every outfit (and their GCS
  /// images) inside it.
  Future<void> deleteGroup(int groupId) async {
    debugLog('--- deleteGroup: groupId=$groupId ---');
    final uri = Uri.parse('$_baseUrl/$groupId');
    final res = await withAuth(
      (token) => http.delete(uri, headers: authHeaders(token)),
    );
    decodeMap(res, op: 'deleteGroup');
  }

  /// Flat list (not group-nested) of every outfit that contains all of
  /// [garmentIds].
  Future<List<Outfit>> getOutfitsByGarments(List<int> garmentIds) async {
    debugLog('--- getOutfitsByGarments: garmentIds=$garmentIds ---');
    final uri = Uri.parse('$_baseUrl/by-garments');
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'garment_ids': garmentIds}),
      ),
    );
    final envelope = decodeMap(res, op: 'getOutfitsByGarments');
    final data = envelope['data'];
    if (data is! List) {
      throw Exception('getOutfitsByGarments: response missing list data');
    }
    return data.whereType<Map<String, dynamic>>().map(Outfit.fromJson).toList();
  }
}
