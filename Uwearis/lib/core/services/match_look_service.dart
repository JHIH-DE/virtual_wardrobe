import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/match_a_look.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// Thrown for a non-2xx Match a Look response that isn't a 401 — carries
/// the backend's own `error_code` (see match-look-api.md) so callers can
/// show a specific message for the handful of codes worth distinguishing
/// (no person detected, multiple people, closet too small, ...) instead of
/// one generic failure string.
class MatchLookException implements Exception {
  final String? errorCode;
  final String message;
  const MatchLookException(this.errorCode, this.message);

  @override
  String toString() => 'MatchLookException($errorCode, $message)';
}

class MatchLookService with BaseService {
  static final MatchLookService _instance = MatchLookService._internal();
  static final String _baseUrl = '${AppConfig.fullApiUrl}/match_look';
  factory MatchLookService() => _instance;
  MatchLookService._internal();

  Map<String, dynamic> _decode(http.Response res, {required String op}) {
    throwIfAuthExpired(res);
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw MatchLookException(null, '$op: invalid response');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw MatchLookException(
        body['error_code'] as String?,
        (body['message'] as String?) ?? '$op failed (${res.statusCode})',
      );
    }
    return body;
  }

  /// Steps 1+2 of match-look-api.md's flow: request a signed upload slot,
  /// then PUT the reference photo straight to it.
  Future<InitUploadResult> _initUpload() async {
    final uri = Uri.parse('$_baseUrl/reference/init-upload');
    debugLog('POST $uri');
    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'content_type': 'image/jpeg'}),
          )
          .timeout(const Duration(seconds: 15)),
    );
    debugLog('POST $uri -> ${res.statusCode}');
    final data = _decode(res, op: 'matchLookInitUpload')['data'];
    if (data is! Map<String, dynamic>) {
      throw const MatchLookException(null, 'matchLookInitUpload: no data');
    }
    return InitUploadResult.fromJson(data);
  }

  /// Uploads [localImagePath] as the single active reference look and has
  /// the backend analyze it (step 3, `POST /reference`) — this is the
  /// expensive "AI reads the photo" call, not the closet search
  /// ([matchLook] is separate). Overwrites whatever reference the user had
  /// active before; the backend only ever keeps one per user.
  Future<void> uploadReference(String localImagePath) async {
    final init = await _initUpload();
    debugLog('PUT ${init.uploadUrl}');
    await putJpegToSignedUrl(init.uploadUrl, localImagePath);
    debugLog('PUT ${init.uploadUrl} -> ok');

    final uri = Uri.parse('$_baseUrl/reference');
    debugLog('POST $uri');
    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'object_name': init.objectName}),
          )
          .timeout(const Duration(seconds: 45)),
    );
    debugLog('POST $uri -> ${res.statusCode} ${res.body}');
    _decode(res, op: 'matchLookReference');
  }

  /// Step 5: matches the closet against whichever reference
  /// [uploadReference] most recently analyzed. Takes no body — the
  /// backend re-runs against its stored reference, so this alone is
  /// enough to refresh recommendations after the closet changes.
  Future<MatchALookResult> matchLook() async {
    final uri = Uri.parse('$_baseUrl/match');
    debugLog('POST $uri');
    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 30)),
    );
    debugLog('POST $uri -> ${res.statusCode} ${res.body}');
    final data = _decode(res, op: 'matchLookMatch')['data'];
    if (data is! Map<String, dynamic>) {
      throw const MatchLookException(null, 'matchLookMatch: no data');
    }
    return MatchALookResult.fromJson(data);
  }

  /// Clears the user's active reference look server-side. A 404 (nothing
  /// to remove) is treated as success — same "already gone" tolerance as
  /// [GarmentService.deleteGarment].
  Future<void> removeReference() async {
    final uri = Uri.parse('$_baseUrl/reference');
    debugLog('DELETE $uri');
    final res = await withAuth(
      (token) => http
          .delete(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
    );
    debugLog('DELETE $uri -> ${res.statusCode}');
    if (res.statusCode == 404) return;
    _decode(res, op: 'matchLookRemoveReference');
  }
}
