import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'api_exception.dart';
import 'auth_handler.dart';
import 'auth_storage.dart';

mixin BaseService {
  Map<String, String> authHeaders(String accessToken) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  Future<String> getSafeToken() async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw AuthExpiredException();
    }
    return token;
  }

  /// On 401, refreshes tokens and retries once.
  ///
  /// [retryOnTimeout]: retry once on [TimeoutException] — idempotent reads
  /// only (the timed-out request has often already woken a cold backend).
  ///
  /// Throws [AuthExpiredException] only when the session can't be
  /// recovered; a network failure on the refresh call propagates as-is, so
  /// callers can tell "logged out" from "server unavailable".
  Future<http.Response> withAuth(
    Future<http.Response> Function(String token) request, {
    bool retryOnTimeout = false,
  }) async {
    final token = await getSafeToken();
    final res = await _send(request, token, retryOnTimeout);
    if (res.statusCode != 401) return res;

    final refreshed = await _refreshTokens();
    return _send(request, refreshed.accessToken, retryOnTimeout);
  }

  /// Single-flight `/auth/refresh` shared by concurrent 401s: with rotating
  /// (single-use) refresh tokens, parallel refreshes would all but one fail
  /// and log the user out of a still-valid session.
  static Future<({String accessToken, String refreshToken})>? _refreshInFlight;

  Future<({String accessToken, String refreshToken})> _refreshTokens() {
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<({String accessToken, String refreshToken})> _doRefresh() async {
    final storedRefresh = await AuthStorage.getRefreshToken();
    if (storedRefresh == null) throw AuthExpiredException();

    final refreshRes = await sendTimed(
      () => http
          .post(
            Uri.parse('${AppConfig.fullApiUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': storedRefresh}),
          )
          .timeout(const Duration(seconds: 15)),
    );
    if (refreshRes.statusCode != 200) {
      final rejected = ApiException.fromResponse(refreshRes);
      debugLog(
        'auth/refresh rejected: ${rejected.statusCode} '
        'error_code=${rejected.errorCode}',
      );
      throw AuthExpiredException();
    }

    final body = jsonDecode(refreshRes.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final newAccessToken = data?['access_token'] as String?;
    final newRefreshToken = data?['refresh_token'] as String?;
    if (newAccessToken == null || newRefreshToken == null) {
      throw AuthExpiredException();
    }

    await AuthStorage.saveAccessToken(newAccessToken);
    await AuthStorage.saveRefreshToken(newRefreshToken);
    return (accessToken: newAccessToken, refreshToken: newRefreshToken);
  }

  Future<http.Response> _send(
    Future<http.Response> Function(String token) request,
    String token,
    bool retryOnTimeout,
  ) async {
    try {
      return await sendTimed(() => request(token));
    } on TimeoutException {
      if (!retryOnTimeout) rethrow;
      debugLog('<<< timed out — retrying once after 1s');
      await Future<void>.delayed(const Duration(seconds: 1));
      return sendTimed(() => request(token));
    }
  }

  /// Debug-logs method, path, status and elapsed ms for one HTTP send.
  /// Only the URL path is logged — never tokens, headers or query strings.
  Future<http.Response> sendTimed(Future<http.Response> Function() send) async {
    final sw = Stopwatch()..start();
    try {
      final res = await send();
      sw.stop();
      final req = res.request;
      debugLog(
        '<<< ${req?.method ?? 'HTTP'} ${req?.url.path ?? '?'} '
        '-> ${res.statusCode} in ${sw.elapsedMilliseconds}ms',
      );
      return res;
    } catch (e) {
      sw.stop();
      debugLog('<<< HTTP failed in ${sw.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  /// Decodes a JSON object response. Every failure (non-2xx, malformed
  /// body) is an [ApiException]; the raw body is only debug-logged, under
  /// [op].
  Map<String, dynamic> decodeMap(http.Response res, {required String op}) {
    throwIfAuthExpired(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugLog('decodeMap: $op failed (${res.statusCode}): ${res.body}');
      throw ApiException.fromResponse(res);
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (e) {
      debugLog('decodeMap: $op returned invalid JSON: ${res.body}');
      throw ApiException(
        statusCode: res.statusCode,
        message: 'Invalid response',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      debugLog('decodeMap: $op returned a non-object JSON body: ${res.body}');
      throw ApiException(
        statusCode: res.statusCode,
        message: 'Invalid response',
      );
    }
    return decoded;
  }

  void throwIfAuthExpired(http.Response res) {
    if (res.statusCode == 401) throw AuthExpiredException();
  }

  /// Idempotent DELETE: `404` (already gone) counts as success. Other
  /// failures go through [errorDecode] ([decodeMap] by default).
  Future<void> deleteIdempotent(
    Uri uri, {
    required String op,
    Duration timeout = const Duration(seconds: 15),
    Map<String, dynamic> Function(http.Response res, {required String op})?
    errorDecode,
  }) async {
    final res = await withAuth(
      (token) => http.delete(uri, headers: authHeaders(token)).timeout(timeout),
    );
    throwIfAuthExpired(res);
    if (res.statusCode == 404) return;
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    (errorDecode ?? decodeMap)(res, op: op);
  }

  /// Step 2 of the init-upload → PUT → complete flow.
  Future<void> putJpegToSignedUrl(
    String uploadUrl,
    String localPath, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final bytes = await File(localPath).readAsBytes();
    final res = await http
        .put(
          Uri.parse(uploadUrl),
          headers: {'Content-Type': 'image/jpeg'},
          body: bytes,
        )
        .timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PUT to signed url failed (${res.statusCode})');
    }
  }
}

class InitUploadResult {
  final String uploadUrl;
  final String objectName;
  const InitUploadResult({required this.uploadUrl, required this.objectName});

  factory InitUploadResult.fromJson(Map<String, dynamic> json) {
    return InitUploadResult(
      uploadUrl: json['upload_url'] ?? '',
      objectName: json['object_name'] ?? '',
    );
  }
}
