import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/outfit.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import '../utils/signed_url.dart';
import 'base_service.dart';

/// OutfitGroup + Outfit API. Every outfit lives in a group; `generate`
/// creates and renders in one synchronous call. [getAllOutfits] and
/// [getOutfitsByGarments] return flat lists.
///
/// Singleton only for [_groupCache]; every mutation invalidates its group.
class OutfitService with BaseService {
  static final OutfitService _instance = OutfitService._internal();
  static final String _baseUrl = '${AppConfig.fullApiUrl}/outfit';
  factory OutfitService() => _instance;
  OutfitService._internal();

  final Map<int, List<Outfit>> _groupCache = {};

  Future<int> createGroup({String type = 'general'}) async {
    debugLog('--- createGroup: type=$type ---');
    final uri = Uri.parse(_baseUrl);
    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'type': type}),
          )
          .timeout(const Duration(seconds: 15)),
    );
    final envelope = decodeMap(res, op: 'createGroup');
    final data = envelope['data'];
    final groupId = data is Map<String, dynamic>
        ? (data['group_id'] as num?)?.toInt()
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
        'sort': ?sort,
      },
    );
    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );
    final envelope = decodeMap(res, op: 'getAllOutfits');
    final data = envelope['data'];
    final items = data is Map<String, dynamic> ? data['items'] : null;
    if (items is! List) {
      throw Exception('getAllOutfits: response missing items list');
    }
    // One representative per group; it carries the group's real version
    // count (Outfit.versionCount) for totals like Style Taste's stat.
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
        final groupName = group['name'] as String?;
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
            groupName: groupName,
            clearGroupName: groupName == null,
          ),
        );
      }
    }
    return outfits;
  }

  /// Creates and renders in one call (no separate save step). Pass
  /// [groupId] to add a version to an existing group; omit it to create a
  /// new [type] group.
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
      'background_id': ?backgroundId,
      'is_favorite': isFavorite,
    };
    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token), body: jsonEncode(payload))
          // Synchronous AI render; backend rate-limit retries can stack.
          .timeout(const Duration(seconds: 90)),
    );
    final envelope = decodeMap(res, op: 'generateOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('generateOutfit: response missing outfit data object');
    }
    _groupCache.remove(groupId);
    return Outfit.fromJson(data);
  }

  /// Re-renders in place (same id and metadata, new image). Omit
  /// [backgroundId] to reuse the current background.
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
    final payload = <String, dynamic>{'background_id': ?backgroundId};
    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token), body: jsonEncode(payload))
          // Synchronous AI render; backend rate-limit retries can stack.
          .timeout(const Duration(seconds: 90)),
    );
    final envelope = decodeMap(res, op: 'regenerateOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('regenerateOutfit: response missing outfit data object');
    }
    _groupCache.remove(groupId);
    return Outfit.fromJson(data);
  }

  Future<Outfit> getOutfit(int groupId, int outfitId) async {
    debugLog('--- getOutfit: groupId=$groupId outfitId=$outfitId ---');
    final uri = Uri.parse('$_baseUrl/$groupId/$outfitId');
    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );
    final envelope = decodeMap(res, op: 'getOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getOutfit: response missing outfit data object');
    }
    return Outfit.fromJson(data);
  }

  /// Partial update — null fields are left untouched.
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
      'is_favorite': ?isFavorite,
      'name': ?name,
      'style': ?style,
      'season': ?season,
    };
    final res = await withAuth(
      (token) => http
          .patch(uri, headers: authHeaders(token), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15)),
    );
    final envelope = decodeMap(res, op: 'updateOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('updateOutfit: response missing outfit data object');
    }
    _groupCache.remove(groupId);
    return Outfit.fromJson(data);
  }

  /// Deletes a single outfit; the parent group is untouched even if this
  /// was its last outfit.
  Future<void> deleteOutfit(int groupId, int outfitId) async {
    debugLog('--- deleteOutfit: groupId=$groupId outfitId=$outfitId ---');
    final uri = Uri.parse('$_baseUrl/$groupId/$outfitId');
    final res = await withAuth(
      (token) => http
          .delete(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
    );
    decodeMap(res, op: 'deleteOutfit');
    _groupCache.remove(groupId);
  }

  /// Every version in [groupId]. Served from [_groupCache] unless an image
  /// URL has expired.
  Future<List<Outfit>> getGroupOutfits(int groupId) async {
    final cached = _groupCache[groupId];
    if (cached != null && !anySignedUrlExpired(cached.map((o) => o.imageUrl))) {
      return cached;
    }

    debugLog('--- getGroupOutfits: groupId=$groupId ---');
    final uri = Uri.parse('$_baseUrl/$groupId');
    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
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
    final groupName = data is Map<String, dynamic>
        ? data['name'] as String?
        : null;
    final result = outfits
        .whereType<Map<String, dynamic>>()
        .map(Outfit.fromJson)
        .map(
          (o) => o.copyWith(
            coverOutfitId: coverOutfitId,
            clearCoverOutfitId: coverOutfitId == null,
            groupName: groupName,
            clearGroupName: groupName == null,
          ),
        )
        .toList();
    _groupCache[groupId] = result;
    return result;
  }

  /// Partial update. [coverOutfitId] is the group's representative in
  /// [getAllOutfits] and must already be rendered.
  Future<void> updateGroup(
    int groupId, {
    String? name,
    int? coverOutfitId,
  }) async {
    debugLog(
      '--- updateGroup: groupId=$groupId name=$name '
      'coverOutfitId=$coverOutfitId ---',
    );
    final uri = Uri.parse('$_baseUrl/$groupId');
    final payload = <String, dynamic>{
      'name': ?name,
      'cover_outfit_id': ?coverOutfitId,
    };
    final res = await withAuth(
      (token) => http
          .patch(uri, headers: authHeaders(token), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15)),
    );
    decodeMap(res, op: 'updateGroup');
    // name/coverOutfitId are copied onto every cached Outfit.
    _groupCache.remove(groupId);
  }

  /// Cascades to every outfit (and its images) in the group.
  Future<void> deleteGroup(int groupId) async {
    debugLog('--- deleteGroup: groupId=$groupId ---');
    final uri = Uri.parse('$_baseUrl/$groupId');
    final res = await withAuth(
      (token) => http
          .delete(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
    );
    decodeMap(res, op: 'deleteGroup');
    _groupCache.remove(groupId);
  }

  /// Every outfit that contains all of [garmentIds].
  Future<List<Outfit>> getOutfitsByGarments(List<int> garmentIds) async {
    debugLog('--- getOutfitsByGarments: garmentIds=$garmentIds ---');
    final uri = Uri.parse('$_baseUrl/by-garments');
    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'garment_ids': garmentIds}),
          )
          .timeout(const Duration(seconds: 15)),
    );
    final envelope = decodeMap(res, op: 'getOutfitsByGarments');
    final data = envelope['data'];
    if (data is! List) {
      throw Exception('getOutfitsByGarments: response missing list data');
    }
    return data.whereType<Map<String, dynamic>>().map(Outfit.fromJson).toList();
  }

  /// Session boundary only (logout / session expiry), so the next user
  /// can't see the previous user's cached groups.
  void clearGroupCache() => _groupCache.clear();
}
