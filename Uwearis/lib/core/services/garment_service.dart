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

/// Non-2xx, non-401 `closet-analysis` response, carrying the backend's
/// `error_code` (e.g. `GARMENT_NOT_FOUND`).
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

  Future<Garment> completeUpload(
    Garment garment,
    Map<String, dynamic>? metaData,
  ) async {
    debugLog('--- completeUpload ---');
    final uri = Uri.parse('$_baseUrl/complete');

    // Send analyze-instant's whole (user-edited) metadata map: any field
    // left out of `metadata` is stored as null.
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
          // Longer than the other CRUD calls: `complete` re-downloads the
          // upload and re-runs background removal server-side.
          .timeout(const Duration(seconds: 30)),
    );

    final envelope = decodeMap(res, op: 'completeUpload');
    final data = envelope['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('completeUpload: response missing data');
    }
    return Garment.fromJson(data);
  }

  /// The whole closet, walking every page. Includes soft-deleted garments
  /// so an outfit referencing one can still resolve it; browse/pick screens
  /// must filter through [ActiveGarmentsX.active] themselves.
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

  /// Without [includeDeleted], a soft-deleted id 404s like a nonexistent
  /// one — pass it when the id may be stale (e.g. an outfit's garment_ids).
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
            body: jsonEncode(_patchPayload(garment)),
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

  /// Only PATCH-editable fields (`object_name` / `image_url` are rejected
  /// with `FIELD_NOT_EDITABLE`).
  ///
  /// fit / silhouette / sleeve_length / crop_length are sent only for a
  /// category they apply to (the backend clears them on a category change).
  /// PATCH validates them strictly (400 `INVALID_GARMENT_ATTRIBUTE`), so `""`
  /// goes as `null`; `crop_length` isn't nullable, so it's sent only with a value.
  static Map<String, dynamic> _patchPayload(Garment garment) {
    String? valueOrNull(String? v) => (v == null || v.isEmpty) ? null : v;
    final category = garment.category;
    final cropLength = valueOrNull(garment.cropLength);
    return {
      'name': garment.name,
      'category': category.apiValue,
      'sub_category': garment.subCategory,
      'brand': garment.brand,
      'color': garment.color,
      'price': garment.price?.round(),
      'purchase_date': garment.purchaseDateApiValue,
      if (garment.thickness > 0) 'thickness': garment.thickness,
      if (garment.formality > 0) 'formality': garment.formality,
      if (garmentFitCategories.contains(category)) ...{
        'fit': valueOrNull(garment.fit),
        'silhouette': valueOrNull(garment.silhouette),
      },
      if (garmentSleeveLengthCategories.contains(category))
        'sleeve_length': valueOrNull(garment.sleeveLength),
      if (garmentCropLengthCategories.contains(category) && cropLength != null)
        'crop_length': cropLength,
    };
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

    final cached = _cache[garmentId];
    if (cached != null) {
      _cache[garmentId] = cached.copyWith(isFavorite: isFavorite);
    }
  }

  /// Un-deletes a soft-deleted garment.
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
      // Backend caps analysis at 100s (AI_ANALYSIS_TIMEOUT); the headroom
      // lets the server's own error arrive before a client timeout.
      final streamedRes = await request.send().timeout(
        const Duration(seconds: 110),
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
        '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.webp',
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

  /// AI closet analysis. With [garmentId], analyzes a saved garment and
  /// caches the result. Without it, [fields] describes an unsaved garment
  /// (`category` required, else 422); the target comes back as
  /// `garment_id: 0`, `image_url: ""` and isn't cached.
  ///
  /// Always hits the network; a failure leaves the cache untouched.
  Future<ClosetAnalysis> closetAnalysis(
    int? garmentId, [
    Map<String, dynamic>? fields,
  ]) async {
    debugLog('--- closetAnalysis: $garmentId ---');
    final uri = Uri.parse('$_baseUrl/closet-analysis');
    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode(
              garmentId != null ? {'garment_id': garmentId} : {...?fields},
            ),
          )
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
    if (garmentId != null) {
      await _saveClosetAnalysisCache(garmentId, result);
    }
    return result;
  }

  /// Writes a result the caller already has (a promoted Add-mode preview,
  /// or one with refreshed image URLs). A preview's sentinel target entries
  /// must be re-pointed at [garmentId] first.
  Future<void> cacheClosetAnalysis(int garmentId, ClosetAnalysis analysis) {
    return _saveClosetAnalysisCache(garmentId, analysis);
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
      // Not fatal — the caller already has the result.
      debugLog('closetAnalysis: failed to persist cache for $garmentId: $e');
    }
  }

  /// Last persisted [closetAnalysis] result for [garmentId]. Deliberately no
  /// TTL — re-analyzing is the user's call; cleared only by [deleteGarment]
  /// or [clearClosetAnalysisCache].
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

  /// Called at session end: keys aren't scoped by user (there's no local
  /// user id), so another user on the device would otherwise see these.
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

  /// Session-end only, so the next user can't hit the previous user's
  /// cached copies.
  void clearGarmentCache() => _cache.clear();
}
