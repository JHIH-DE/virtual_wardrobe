import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/outfit.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

class OutfitService with BaseService {
  // Backend route is still `/outfits` — not renamed here since that's a
  // live API contract, not just app-side wording.
  static final String _baseUrl = '${AppConfig.fullApiUrl}/outfits';

  Future<Map<String, dynamic>> createOutfit({
    required List<int> garmentIds,
    required String type,
    String style = 'Minimal',
    String? name,
    int? backgroundId,
  }) async {
    debugLog('--- createOutfit garmentIds: $garmentIds ---');
    final uri = Uri.parse(_baseUrl);
    final payload = <String, dynamic>{
      'garment_ids': garmentIds,
      "job_type": type,
      "style": style,
      if (name != null) 'name': name,
      if (backgroundId != null) 'background_id': backgroundId,
    };
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode(payload),
      ),
    );
    final envelope = decodeMap(res, op: 'createOutfit');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    debugLog('--- createOutfit raw response: $data ---');
    return data;
  }

  /// Combines [createOutfit] + [createLook] into one call for the common
  /// "create an outfit and immediately render its first look" flow. If Step
  /// 1 ([createOutfit]) fails, nothing was created and the failure
  /// propagates as-is. If Step 2 ([createLook]) fails, the outfit already
  /// exists on the backend — the failure is wrapped in
  /// [OutfitRenderException] carrying `outfitId` so the caller can retry
  /// rendering via [createLook] directly instead of creating a duplicate
  /// outfit.
  Future<Map<String, dynamic>> createOutfitAndRender({
    required List<int> garmentIds,
    String style = 'Minimal',
    String type = 'general',
    String? name,
    int? backgroundId,
    List<int>? accessoryGarmentIds,
  }) async {
    debugLog('--- createOutfitAndRender garmentIds: $garmentIds ---');
    final outfitResponse = await createOutfit(
      garmentIds: garmentIds,
      type: type,
      style: style,
      name: name,
      backgroundId: backgroundId,
    );
    final outfitId = outfitResponse['outfit_id'] as int?;
    if (outfitId == null) {
      throw Exception('createOutfitAndRender: response missing outfit_id');
    }

    try {
      final lookResponse = await createLook(
        outfitId,
        accessoryGarmentIds: accessoryGarmentIds,
        backgroundId: backgroundId,
      );
      return {
        'outfit_id': outfitId,
        'look_id': lookResponse['look_id'],
        'status': lookResponse['status'],
      };
    } catch (e) {
      throw OutfitRenderException(outfitId, e);
    }
  }

  Future<List<Outfit>> getAllOutfits({
    String? jobType,
    int page = 1,
    int size = 100,
    String? sort,
  }) async {
    debugLog(
      '--- getAllOutfits: jobType=$jobType page=$page size=$size '
      'sort=$sort ---',
    );
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        if (jobType != null) 'job_type': jobType,
        'page': '$page',
        'size': '$size',
        if (sort != null) 'sort': sort,
      },
    );
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'getAllOutfits');
    final data = envelope['data'] as Map<String, dynamic>?;
    final items = data?['items'];
    if (items is! List) {
      throw Exception('getAllOutfits: response missing items list');
    }
    final imageUrlsByOutfitId = {
      for (final j in items.whereType<Map<String, dynamic>>())
        (j['outfit_id'] ?? primaryLookOf(j)?['outfit_id']): primaryLookOf(
          j,
        )?['result_image_url'],
    };
    debugLog(
      '--- getAllOutfits look_id 0 image by outfit_id: '
      '$imageUrlsByOutfitId ---',
    );

    return items
        .whereType<Map<String, dynamic>>()
        .map((j) => Outfit.fromJson(j))
        .toList();
  }

  /// Regenerates a new look on an already-existing outfit, reusing its
  /// existing core garment combo — unlike [createOutfit], which always
  /// starts a brand new outfit. [accessoryGarmentIds]: leave null to reuse
  /// the previous look's accessories, pass `[]` for none this time, or a
  /// list to swap to those specific accessories. [backgroundId]: the
  /// backend's background lookup id (see `SceneOption.backgroundId`); leave
  /// null to reuse whatever background the previous look used.
  Future<Map<String, dynamic>> createLook(
    int outfitId, {
    List<int>? accessoryGarmentIds,
    int? backgroundId,
  }) async {
    debugLog(
      '--- createLook: $outfitId / '
      'accessoryGarmentIds=$accessoryGarmentIds / '
      'backgroundId=$backgroundId ---',
    );
    final uri = Uri.parse('$_baseUrl/$outfitId/looks');
    final payload = <String, dynamic>{
      if (accessoryGarmentIds != null)
        'accessory_garment_ids': accessoryGarmentIds,
      if (backgroundId != null) 'background_id': backgroundId,
    };
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode(payload),
      ),
    );
    final envelope = decodeMap(res, op: 'createLook');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    debugLog('--- createLook raw response: $data ---');
    return data;
  }

  /// Regenerates [lookId] in place: reuses its existing accessories/
  /// background and re-runs the AI render, overwriting the old image on
  /// success — no new history entry is created. To change accessories/
  /// background or keep history, use [createLook] instead.
  Future<Map<String, dynamic>> regenerateLook(int outfitId, int lookId) async {
    debugLog('--- regenerateLook: outfitId=$outfitId / lookId=$lookId ---');
    final uri = Uri.parse('$_baseUrl/$outfitId/looks/$lookId/regenerate');
    final res = await withAuth(
      (token) => http.post(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'regenerateLook');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    debugLog('--- regenerateLook raw response: $data ---');
    return data;
  }

  Future<Map<String, dynamic>> getOutfit(int outfitId) async {
    debugLog('--- getOutfit ---');
    final uri = Uri.parse('$_baseUrl/$outfitId');
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'getOutfit');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('getOutfit: response missing outfit data object');
    }
    return data;
  }

  Future<void> setName(int outfitId, {required String name}) async {
    debugLog('--- setName: $outfitId / $name ---');
    final uri = Uri.parse('$_baseUrl/$outfitId');
    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'name': name}),
      ),
    );
    decodeMap(res, op: 'setName');
  }

  /// Updates an outfit's season tags (confirmed via Update Outfit's
  /// `PATCH /outfits/{outfit_id}` schema — `season`, alongside `style` and
  /// `name`, independently settable).
  Future<void> setSeason(int outfitId, {required List<String> season}) async {
    debugLog('--- setSeason: $outfitId / $season ---');
    final uri = Uri.parse('$_baseUrl/$outfitId');
    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'season': season}),
      ),
    );
    debugLog('--- setSeason response (${res.statusCode}): ${res.body} ---');
    decodeMap(res, op: 'setSeason');
  }

  /// Updates an outfit's style tags — see [setSeason].
  Future<void> setStyle(int outfitId, {required List<String> style}) async {
    debugLog('--- setStyle: $outfitId / $style ---');
    final uri = Uri.parse('$_baseUrl/$outfitId');
    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'style': style}),
      ),
    );
    debugLog('--- setStyle response (${res.statusCode}): ${res.body} ---');
    decodeMap(res, op: 'setStyle');
  }

  Future<List<Outfit>> getOutfitsByGarments(List<int> garmentIds) async {
    debugLog('--- getOutfitsByGarments: $garmentIds ---');
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
    debugLog('--- getOutfitsByGarments raw response: ${res.body} ---');
    // Same envelope drift as getAllOutfits: `data` used to be the list
    // itself, but list-style endpoints on this backend have been migrating
    // to a paginated `{items: [...], total, page, size}` wrapper — support
    // both instead of assuming whichever shape happened to be true last.
    final items = data is Map<String, dynamic> ? data['items'] : data;
    if (items is! List) {
      throw Exception('getOutfitsByGarments: response missing list data');
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map((j) => Outfit.fromJson(j))
        .toList();
  }

  Future<void> deleteOutfit(int outfitId) async {
    debugLog('--- deleteOutfit ---');
    final uri = Uri.parse('$_baseUrl/$outfitId');
    final res = await withAuth(
      (token) => http.delete(uri, headers: authHeaders(token)),
    );

    if (res.statusCode == 200 ||
        res.statusCode == 204 ||
        res.statusCode == 404) {
      return;
    }
    throw Exception('deleteOutfit failed (${res.statusCode}): ${res.body}');
  }

  /// Updates a single look's `is_favorite` flag — collects this one
  /// generation's render (the outfit-level favorite has been retired along
  /// with its backend endpoint).
  Future<void> setLookFavorite(
    int outfitId,
    int lookId, {
    required bool isFavorite,
  }) async {
    debugLog(
      '--- setLookFavorite: outfitId=$outfitId / lookId=$lookId / '
      '$isFavorite ---',
    );
    final uri = Uri.parse('$_baseUrl/$outfitId/looks/$lookId');
    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'is_favorite': isFavorite}),
      ),
    );
    decodeMap(res, op: 'setLookFavorite');
  }

  /// Deletes a single generation (one entry of an outfit's `looks[]`).
  /// Allowed down to zero remaining looks — the outfit itself is untouched.
  Future<void> deleteLook(int outfitId, int lookId) async {
    debugLog('--- deleteLook: outfitId=$outfitId / lookId=$lookId ---');
    final uri = Uri.parse('$_baseUrl/$outfitId/looks/$lookId');
    final res = await withAuth(
      (token) => http.delete(uri, headers: authHeaders(token)),
    );

    if (res.statusCode == 200 ||
        res.statusCode == 204 ||
        res.statusCode == 404) {
      return;
    }
    throw Exception('deleteLook failed (${res.statusCode}): ${res.body}');
  }
}

/// Thrown by [OutfitService.createOutfitAndRender] when the outfit was
/// created successfully but rendering its first look failed. [outfitId]
/// lets the caller retry via [OutfitService.createLook] on the existing
/// outfit instead of creating a duplicate one.
class OutfitRenderException implements Exception {
  final int outfitId;
  final Object cause;

  OutfitRenderException(this.outfitId, this.cause);

  @override
  String toString() =>
      'OutfitRenderException(outfitId: $outfitId, cause: $cause)';
}
