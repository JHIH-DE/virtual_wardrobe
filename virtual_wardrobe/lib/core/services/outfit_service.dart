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
  }) async {
    debugLog('--- createOutfit garmentIds: $garmentIds ---');
    final uri = Uri.parse(_baseUrl);
    final payload = <String, dynamic>{
      'garment_ids': garmentIds,
      "job_type": type,
      "style": style,
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

  Future<List<Outfit>> getAllOutfits() async {
    debugLog('--- getAllOutfits ---');
    final uri = Uri.parse(_baseUrl);
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'getAllOutfits');
    final data = envelope['data'];
    if (data is! List) {
      throw Exception('getAllOutfits: response missing list data');
    }
    final imageUrlsByOutfitId = {
      for (final j in data.whereType<Map<String, dynamic>>())
        (j['outfit_id'] ?? primaryLookOf(j)?['outfit_id']): primaryLookOf(
          j,
        )?['result_image_url'],
    };
    debugLog(
      '--- getAllOutfits look_id 0 image by outfit_id: '
      '$imageUrlsByOutfitId ---',
    );

    return data
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

  Future<Map<String, dynamic>> getOutfit(int jobId) async {
    debugLog('--- getOutfit ---');
    final uri = Uri.parse('$_baseUrl/$jobId');
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

  Future<void> setFavorite(int outfitId, {required bool isFavorite}) async {
    debugLog('--- setFavorite: $outfitId / $isFavorite ---');
    final uri = Uri.parse('$_baseUrl/$outfitId');
    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'is_favorite': isFavorite}),
      ),
    );
    decodeMap(res, op: 'setFavorite');
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

  Future<void> setSaved(int outfitId, {required bool isSaved}) async {
    debugLog('--- setSaved: $outfitId / $isSaved ---');
    final uri = Uri.parse('$_baseUrl/$outfitId');
    final res = await withAuth(
      (token) => http.patch(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'is_saved': isSaved}),
      ),
    );
    decodeMap(res, op: 'setSaved');
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
    if (data is! List) {
      throw Exception('getOutfitsByGarments: response missing list data');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map((j) => Outfit.fromJson(j))
        .toList();
  }

  Future<void> deleteOutfit(int jobId) async {
    debugLog('--- deleteOutfit ---');
    final uri = Uri.parse('$_baseUrl/$jobId');
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
