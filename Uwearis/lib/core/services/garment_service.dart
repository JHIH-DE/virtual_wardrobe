import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/closet_analysis.dart';
import '../../data/garment.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import '../utils/signed_url.dart';
import 'base_service.dart';

class AnalyzeGarmentResult {
  final Map<String, dynamic> metadata;
  final String? processedImagePath;

  const AnalyzeGarmentResult({required this.metadata, this.processedImagePath});
}

/// Thrown for a non-2xx `closet-analysis` response that isn't a 401 —
/// carries the backend's own `error_code` (see garments-api.md §8) so the
/// page can show a specific message for `GARMENT_NOT_FOUND` instead of the
/// generic AI-failure fallback.
class ClosetAnalysisException implements Exception {
  final String? errorCode;
  final String message;
  const ClosetAnalysisException(this.errorCode, this.message);

  @override
  String toString() => 'ClosetAnalysisException($errorCode, $message)';
}

class GarmentService with BaseService {
  static final GarmentService _instance = GarmentService._internal();
  static final String _baseUrl = '${AppConfig.fullApiUrl}/garments';
  factory GarmentService() => _instance;
  GarmentService._internal();

  final Map<int, Garment> _cache = {};

  /// SharedPreferences key prefix for a persisted [closetAnalysis] result —
  /// see [cachedClosetAnalysis]'s own doc comment for the caching policy.
  static const String _closetAnalysisKeyPrefix = 'closet_analysis_';
  static String _closetAnalysisKey(int garmentId) =>
      '$_closetAnalysisKeyPrefix$garmentId';

  Future<InitUploadResult> initUpload() async {
    debugLog('--- initUpload ---');
    final uri = Uri.parse('$_baseUrl/init-upload');
    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'content_type': 'image/jpeg'}),
          )
          .timeout(const Duration(seconds: 15)),
    );

    final envelope = decodeMap(res, op: 'initUpload');
    final data = envelope['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('initUpload: invalid response json');
    }

    return InitUploadResult.fromJson(data);
  }

  Future<void> uploadImage(String uploadUrl, String localPath) async {
    debugLog('--- uploadImage ---');
    await putJpegToSignedUrl(uploadUrl, localPath);
  }

  Future<Garment> completeUpload(
    Garment garment,
    Map<String, dynamic>? metaData,
  ) async {
    debugLog('--- completeUpload ---');
    final uri = Uri.parse('$_baseUrl/complete');

    // Per the garments API: category / sub_category / name / color are the
    // top-level body fields; thickness / formality / fit / material / style /
    // crop_length / description ride inside `metadata`.
    final payload = <String, dynamic>{
      'name': garment.name,
      'category': garment.category.apiValue,
      'sub_category': garment.subCategory,
      'object_name': garment.objectName,
      'brand': garment.brand,
      'color': garment.color,
      'price': garment.price,
      'purchase_date': garment.purchaseDateApiValue,
      'metadata': metaData,
    };

    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15)),
    );

    final envelope = decodeMap(res, op: 'completeUpload');
    final data = envelope['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('completeUpload: response missing data');
    }
    return Garment.fromJson(data);
  }

  /// Fetches the caller's whole closet — including soft-deleted garments
  /// (`include_deleted=true`), so a saved outfit that references one can
  /// still resolve it from this same cache-warming list instead of every
  /// such lookup needing its own network round trip (see
  /// `OutfitDetailsPage._loadGarments`). Every "browse/pick a garment"
  /// screen must filter the result through [ActiveGarmentsX.active] itself
  /// — this method deliberately does not, since the one place that *wants*
  /// deleted entries needs the raw list. The backend paginates this
  /// endpoint (`data: {items, total, page, size}` instead of a bare array),
  /// so this walks every page at the largest allowed `size` and returns one
  /// flat list — every existing caller (`garmentsProvider`,
  /// `trip_details_page`) expects "the whole closet" as a `List<Garment>`,
  /// not a page at a time.
  Future<List<Garment>> getGarments() async {
    debugLog('--- getGarments ---');
    const pageSize = 100; // backend's documented max `size`
    final garments = <Garment>[];
    var page = 1;

    while (true) {
      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'page': '$page',
          'size': '$pageSize',
          'include_deleted': 'true',
        },
      );
      final res = await withAuth(
        (token) => http
            .get(uri, headers: authHeaders(token))
            .timeout(const Duration(seconds: 15)),
        retryOnTimeout: true,
      );
      final envelope = decodeMap(res, op: 'getGarments');
      final data = envelope['data'] as Map<String, dynamic>?;
      final items = data?['items'];
      if (items is! List) {
        throw Exception('getGarments: response missing items list');
      }

      garments.addAll(
        items.whereType<Map<String, dynamic>>().map(Garment.fromJson),
      );

      final total = (data?['total'] as num?)?.toInt() ?? garments.length;
      if (items.length < pageSize || garments.length >= total) break;
      page++;
    }

    for (final g in garments) {
      if (g.id != null) _cache[g.id!] = g;
    }
    return garments;
  }

  /// [includeDeleted] must be true to resolve a garment id that's been
  /// soft-deleted — otherwise this 404s exactly like a nonexistent one. A
  /// cache hit short-circuits before this matters (whatever's cached,
  /// deleted or not, already reflects reality), so pass it whenever the
  /// caller can't guarantee the id is still active — e.g. an outfit's own
  /// `garment_ids`, which can reference one after it's since been removed
  /// from the closet.
  Future<Garment> getGarment(
    int garmentId, {
    bool includeDeleted = false,
  }) async {
    final cached = _cache[garmentId];
    if (cached != null) {
      final url = cached.imageUrl;
      final stale = url != null && url.isNotEmpty && isSignedUrlExpired(url);
      if (!stale) return cached;
    }

    debugLog('--- getGarment: $garmentId  ---');
    final uri = Uri.parse('$_baseUrl/$garmentId').replace(
      queryParameters: includeDeleted ? {'include_deleted': 'true'} : null,
    );
    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );
    final envelope = decodeMap(res, op: 'getGarment');
    final data = envelope['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('getGarment: response missing data');
    }

    final garment = Garment.fromJson(data);
    _cache[garmentId] = garment;
    return garment;
  }

  Future<void> deleteGarment(int garmentId) async {
    debugLog('--- deleteGarment: $garmentId ---');
    await deleteIdempotent(
      Uri.parse('$_baseUrl/$garmentId'),
      op: 'deleteGarment',
    );
    _cache.remove(garmentId);
    // Only this garment's own analysis — a deleted garment can't be
    // re-analyzed, but every other garment's cached result is unaffected.
    await _removeClosetAnalysisCache(garmentId);
  }

  Future<Garment> updateGarment(Garment garment) async {
    debugLog('--- updateGarment ---');
    if (garment.id == null) throw Exception('updateGarment: missing id');
    final uri = Uri.parse('$_baseUrl/${garment.id}');
    final res = await withAuth(
      (token) => http
          .patch(
            uri,
            headers: authHeaders(token),
            body: jsonEncode(garment.toJson()),
          )
          .timeout(const Duration(seconds: 15)),
    );

    final envelope = decodeMap(res, op: 'updateGarment');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('updateGarment: response missing data');

    final updated = Garment.fromJson(data);
    if (updated.id != null) _cache[updated.id!] = updated;
    return updated;
  }

  Future<void> setFavorite(int garmentId, {required bool isFavorite}) async {
    debugLog('--- setFavorite: $garmentId / $isFavorite ---');
    final uri = Uri.parse('$_baseUrl/$garmentId');
    final res = await withAuth(
      (token) => http
          .patch(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'is_favorite': isFavorite}),
          )
          .timeout(const Duration(seconds: 15)),
    );
    decodeMap(res, op: 'setFavorite');

    // Keep the in-memory cache coherent with the state the server just
    // accepted. Runs only after decodeMap: a non-2xx, a 401 (AuthExpired),
    // or a malformed body all throw above and leave the cache untouched.
    final cached = _cache[garmentId];
    if (cached != null) {
      _cache[garmentId] = cached.copyWith(isFavorite: isFavorite);
    }
  }

  /// Un-deletes a soft-deleted garment (`PATCH {is_deleted: false}`) — the
  /// only way to reverse [deleteGarment]'s soft-delete path. Returns the
  /// refreshed [Garment] so a caller showing it (e.g. a "restore" action on
  /// an outfit's deleted-garment card) can swap straight to the live card.
  Future<Garment> restoreGarment(int garmentId) async {
    debugLog('--- restoreGarment: $garmentId ---');
    final uri = Uri.parse('$_baseUrl/$garmentId');
    final res = await withAuth(
      (token) => http
          .patch(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'is_deleted': false}),
          )
          .timeout(const Duration(seconds: 15)),
    );
    final envelope = decodeMap(res, op: 'restoreGarment');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('restoreGarment: response missing data');

    final restored = Garment.fromJson(data);
    _cache[garmentId] = restored;
    return restored;
  }

  Future<AnalyzeGarmentResult> analyzeGarment(String localPath) async {
    debugLog('--- analyzeGarment ---');
    final uri = Uri.parse('$_baseUrl/analyze-instant');
    final res = await withAuth((token) async {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      final mimeType = lookupMimeType(localPath) ?? 'image/jpeg';
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          localPath,
          contentType: MediaType.parse(mimeType),
        ),
      );
      // Generous: this is an AI vision call and the first one after an idle
      // period also eats the backend's cold start.
      final streamedRes = await request.send().timeout(
        const Duration(seconds: 60),
      );
      return http.Response.fromStream(streamedRes);
    });

    final envelope = decodeMap(res, op: 'analyzeInstantGarment');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? {};
    final metadata = (data['metadata'] as Map<String, dynamic>?) ?? {};

    String? processedImagePath;
    final base64Str = data['processed_image_base64'] as String?;
    if (base64Str != null && base64Str.isNotEmpty) {
      final bytes = base64Decode(base64Str);
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes);
      processedImagePath = file.path;
    }

    return AnalyzeGarmentResult(
      metadata: metadata,
      processedImagePath: processedImagePath,
    );
  }

  Map<String, dynamic> _decodeClosetAnalysis(
    http.Response res, {
    required String op,
  }) {
    throwIfAuthExpired(res);
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ClosetAnalysisException(null, '$op: invalid response');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ClosetAnalysisException(
        body['error_code'] as String?,
        (body['message'] as String?) ?? '$op failed (${res.statusCode})',
      );
    }
    return body;
  }

  /// Analyzes an already-in-the-closet garment against the user's current
  /// full closet (`POST /garments/{id}/closet-analysis`) — a versatility
  /// level, up to 3 outfit ideas, and up to 3 similar garments. Takes no
  /// body; doesn't write DB — the backend recomputes it fresh on every call
  /// (see [ClosetAnalysis]'s own doc comment). Always hits the network (an
  /// explicit "Analyze with AI" / "Analyze Again" / refresh tap should never
  /// silently serve a stale result) and persists the result to
  /// [cachedClosetAnalysis]'s cache only once the call actually succeeds —
  /// a failed refresh leaves whatever was cached before untouched. Replaced
  /// the now-removed `POST /garments/versatility-score`, which scored a
  /// not-yet-created garment instead of one already in the closet.
  Future<ClosetAnalysis> closetAnalysis(int garmentId) async {
    debugLog('--- closetAnalysis: $garmentId ---');
    final uri = Uri.parse('$_baseUrl/$garmentId/closet-analysis');
    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 45)),
    );
    final data = _decodeClosetAnalysis(res, op: 'closetAnalysis')['data'];
    if (data is! Map<String, dynamic>) {
      throw const ClosetAnalysisException(
        null,
        'closetAnalysis: response missing data',
      );
    }
    final result = ClosetAnalysis.fromJson(data);
    await _saveClosetAnalysisCache(garmentId, result);
    return result;
  }

  Future<void> _saveClosetAnalysisCache(
    int garmentId,
    ClosetAnalysis analysis,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _closetAnalysisKey(garmentId),
        jsonEncode({
          'analysis': analysis.toJson(),
          'analyzed_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      // Not fatal — the caller already has the fresh result in hand; this
      // only means the next page visit won't find it cached.
      debugLog('closetAnalysis: failed to persist cache for $garmentId: $e');
    }
  }

  /// The persisted [closetAnalysis] result for [garmentId], if this garment
  /// has ever been analyzed — lets Garment Details show what it showed last
  /// time instead of the "Analyze with AI" prompt on every fresh visit,
  /// including after an app restart. Backed by `SharedPreferences`
  /// (`shared_preferences` is already a project dependency; nothing new was
  /// introduced for this).
  ///
  /// Deliberately **not** time-boxed: unlike the short-lived caches
  /// elsewhere in this service ([getGarment]'s, keyed off signed-URL
  /// expiry), a closet-analysis result has no natural expiry of its own —
  /// the backend always recomputes fresh when asked (see [ClosetAnalysis]'s
  /// own doc comment), but nothing here decides *when* to ask again. That's
  /// the user's call, via the "Analyze Again" / refresh action — this cache
  /// just remembers whatever the last successful call returned until they
  /// do. Not cleared by reopening the page, an app restart, or another
  /// garment being added/edited/removed — only by [deleteGarment] for this
  /// garment specifically, or [clearClosetAnalysisCache] at logout.
  Future<ClosetAnalysis?> cachedClosetAnalysis(int garmentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_closetAnalysisKey(garmentId));
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final analysisJson = decoded['analysis'] as Map<String, dynamic>?;
      if (analysisJson == null) return null;
      return ClosetAnalysis.fromJson(analysisJson);
    } catch (e) {
      debugLog('closetAnalysis: failed to read cache for $garmentId: $e');
      return null;
    }
  }

  Future<void> _removeClosetAnalysisCache(int garmentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_closetAnalysisKey(garmentId));
    } catch (e) {
      debugLog('closetAnalysis: failed to remove cache for $garmentId: $e');
    }
  }

  /// Clears every persisted closet-analysis result. This app has no stable
  /// local user id to scope a cache key by (see `AuthStorage`'s own doc
  /// comment — it stores only the access/refresh token pair, nothing
  /// identifying), so per-garment keys alone can't tell one signed-in
  /// user's cached analyses apart from another's on a shared device.
  /// Wiping the whole cache at the session boundary is what actually
  /// prevents that leak — called from `clearSignedInSession`
  /// (`auth_handler.dart`), this app's one shared session-boundary cleanup
  /// routine.
  Future<void> clearClosetAnalysisCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where(
        (k) => k.startsWith(_closetAnalysisKeyPrefix),
      );
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugLog('closetAnalysis: failed to clear cache: $e');
    }
  }

  /// Drops every cached [Garment] — call this at a session boundary
  /// (logout / session expiry) alongside every other per-user cache, so
  /// the next signed-in user on this device doesn't see a garment id that
  /// happens to also exist in their own closet resolve to the previous
  /// user's cached copy. Not called anywhere in normal use — every
  /// mutation method above already keeps just the affected entry coherent.
  void clearGarmentCache() => _cache.clear();
}
