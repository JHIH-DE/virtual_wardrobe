import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/match_a_look.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// Non-2xx, non-401 Match a Look response, carrying the backend's
/// `error_code` (no person detected, multiple people, closet too small, ...).
class MatchLookException implements Exception {
  final String? errorCode;
  final String message;
  const MatchLookException(this.errorCode, this.message);

  @override
  String toString() => 'MatchLookException($errorCode, $message)';
}

class MatchLookService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/match_look';

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

  Future<InitUploadResult> _initUpload() async {
    debugLog('--- _initUpload ---');
    final uri = Uri.parse('$_baseUrl/reference/init-upload');
    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'content_type': 'image/jpeg'}),
          )
          .timeout(const Duration(seconds: 15)),
    );
    final data = _decode(res, op: 'matchLookInitUpload')['data'];
    if (data is! Map<String, dynamic>) {
      throw const MatchLookException(null, 'matchLookInitUpload: no data');
    }
    return InitUploadResult.fromJson(data);
  }

  /// Uploads and AI-analyzes the reference look, replacing the user's
  /// previous one (the backend keeps one per user).
  Future<void> uploadReference(String localImagePath) async {
    debugLog('--- uploadReference: $localImagePath ---');
    final init = await _initUpload();
    await putJpegToSignedUrl(init.uploadUrl, localImagePath);

    final uri = Uri.parse('$_baseUrl/reference');
    final res = await withAuth(
      (token) => http
          .post(
            uri,
            headers: authHeaders(token),
            body: jsonEncode({'object_name': init.objectName}),
          )
          .timeout(const Duration(seconds: 45)),
    );
    _decode(res, op: 'matchLookReference');
  }

  /// Matches the closet against the stored reference — enough on its own to
  /// refresh results after the closet changes.
  Future<MatchALookResult> matchLook() async {
    debugLog('--- matchLook ---');
    final uri = Uri.parse('$_baseUrl/match');
    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 30)),
    );
    final data = _decode(res, op: 'matchLookMatch')['data'];
    if (data is! Map<String, dynamic>) {
      throw const MatchLookException(null, 'matchLookMatch: no data');
    }
    return MatchALookResult.fromJson(data);
  }

  /// 404 (nothing to remove) counts as success.
  Future<void> removeReference() async {
    debugLog('--- removeReference ---');
    await deleteIdempotent(
      Uri.parse('$_baseUrl/reference'),
      op: 'matchLookRemoveReference',
      errorDecode: _decode,
    );
  }
}
