import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/crash_handler.dart';
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

  /// On 401, refreshes tokens and retries once.
  ///
  /// [retryOnTimeout]: retry once on [TimeoutException] — idempotent reads
  /// only (the timed-out request has often already woken a cold backend).
  ///
  /// A timeout or transport error on the request itself propagates as-is,
  /// so callers can tell "server unavailable" from "logged out".
  ///
  /// Throws [AuthExpiredException] when this session can't be recovered: no
  /// token, or the refresh's outcome is anything but a stored new token
  /// pair. A retry that 401s again is returned; [decodeMap] turns it into an
  /// [AuthExpiredException]. Refresh tokens are single-use and the backend
  /// revokes every session of a user that reuses one, so a sent refresh
  /// token is never sent again: a refresh that times out, fails in
  /// transport, or answers non-200 or an incomplete body ends the session
  /// ([AuthStorage.distrustSession]) instead of being retried.
  ///
  /// The request belongs to the session signed in when it starts. Once that
  /// session has ended, it throws [SessionChangedException] instead of
  /// refreshing, retrying or returning a reply: the next account's tokens
  /// must never carry this request, and its reply isn't that account's data.
  /// That is not an expiry of the session signed in now, so it must not
  /// reach [AuthExpiredHandler].
  Future<http.Response> withAuth(
    Future<http.Response> Function(String token) request, {
    bool retryOnTimeout = false,
  }) async {
    final session = await _readSession();
    final res = await _send(
      request,
      session.token,
      session.epoch,
      retryOnTimeout,
    );
    if (res.statusCode != 401) return res;

    final refreshed = await _refreshTokens(session.epoch);
    _ensureSession(session.epoch);
    return _send(request, refreshed.accessToken, session.epoch, retryOnTimeout);
  }

  Future<({int epoch, String token})> _readSession() async {
    final epoch = AuthStorage.sessionEpoch;
    final token = await AuthStorage.getAccessToken();
    _ensureSession(epoch);
    if (token == null || token.isEmpty) throw AuthExpiredException();
    return (epoch: epoch, token: token);
  }

  void _ensureSession(int epoch) {
    if (AuthStorage.sessionEpoch != epoch) throw SessionChangedException();
  }

  /// For a flow of several steps (requests, a signed-URL PUT, a download):
  /// captures the session signed in now — synchronously, when this is
  /// called — and returns a check that throws [SessionChangedException]
  /// once that session has ended. Call the check before each further step;
  /// [withAuth] binds only its own request. A later sign-in, even of the
  /// same account, never makes it pass again.
  void Function() sessionGuard() {
    final epoch = AuthStorage.sessionEpoch;
    return () => _ensureSession(epoch);
  }

  /// Single-flight `/auth/refresh` shared by concurrent 401s of one session:
  /// with rotating (single-use) refresh tokens, parallel refreshes would all
  /// but one fail and log the user out of a still-valid session. Another
  /// session's 401 starts its own.
  static _RefreshFlight? _refreshInFlight;

  Future<({String accessToken, String refreshToken})> _refreshTokens(
    int epoch,
  ) {
    final current = _refreshInFlight;
    if (current != null && current.epoch == epoch) return current.future;
    final flight = _RefreshFlight(epoch);
    _refreshInFlight = flight;
    flight.future = _doRefresh(epoch).whenComplete(() {
      if (identical(_refreshInFlight, flight)) _refreshInFlight = null;
    });
    return flight.future;
  }

  Future<({String accessToken, String refreshToken})> _doRefresh(
    int epoch,
  ) async {
    final storedRefresh = await AuthStorage.refreshTokenForRotation(epoch);
    _ensureSession(epoch);
    if (storedRefresh == null) throw AuthExpiredException();

    // From here the stored token may be spent: the backend can rotate it
    // and the reply still never arrive or be unusable. Resending a spent one
    // makes the backend revoke every session of the user, so any outcome
    // but a stored new pair ends this session instead of being retried.
    final ({String accessToken, String refreshToken}) rotated;
    try {
      rotated = await _postRefresh(storedRefresh);
    } catch (e) {
      if (!AuthStorage.distrustSession(epoch)) throw SessionChangedException();
      debugLog('auth/refresh failed (${e.runtimeType}); session ended');
      throw AuthExpiredException();
    }
    _ensureSession(epoch);

    final saved = await AuthStorage.saveRefreshedTokens(
      epoch: epoch,
      accessToken: rotated.accessToken,
      refreshToken: rotated.refreshToken,
    );
    if (!saved) throw SessionChangedException();
    return rotated;
  }

  /// Throws unless the backend answered 200 with a complete token pair.
  Future<({String accessToken, String refreshToken})> _postRefresh(
    String refreshToken,
  ) async {
    final res = await sendTimed(
      () => http
          .post(
            Uri.parse('${AppConfig.fullApiUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 15)),
    );
    if (res.statusCode != 200) {
      final rejected = ApiException.fromResponse(res);
      debugLog(
        'auth/refresh rejected: ${rejected.statusCode} '
        'error_code=${rejected.errorCode}',
      );
      throw rejected;
    }
    final body = jsonDecode(res.body);
    final data = body is Map ? body['data'] : null;
    final access = data is Map ? data['access_token'] : null;
    final refresh = data is Map ? data['refresh_token'] : null;
    if (access is! String ||
        refresh is! String ||
        access.isEmpty ||
        refresh.isEmpty) {
      throw const FormatException('auth/refresh: no token pair in the reply');
    }
    return (accessToken: access, refreshToken: refresh);
  }

  Future<http.Response> _send(
    Future<http.Response> Function(String token) request,
    String token,
    int epoch,
    bool retryOnTimeout,
  ) async {
    http.Response res;
    try {
      res = await sendTimed(() => request(token));
    } on TimeoutException {
      if (!retryOnTimeout) rethrow;
      _ensureSession(epoch);
      debugLog('<<< timed out — retrying once after 1s');
      await Future<void>.delayed(const Duration(seconds: 1));
      _ensureSession(epoch);
      res = await sendTimed(() => request(token));
    }
    _ensureSession(epoch);
    return res;
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
      _reportServerFailure(res);
      return res;
    } catch (e) {
      sw.stop();
      debugLog('<<< HTTP failed in ${sw.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  /// 5xx is a backend fault and 422 means the app sent a request the
  /// backend's schema rejects; both are bugs whatever the caller does with
  /// them. The request id lets the report be matched to api_logs. Only the
  /// URL path is sent, never the query string or body.
  void _reportServerFailure(http.Response res) {
    if (res.statusCode < 500 && res.statusCode != 422) return;
    final error = ApiException.fromResponse(res);
    final req = res.request;
    GlobalErrorHandler.recordNonFatal(
      error,
      StackTrace.current,
      reason:
          'HTTP ${res.statusCode} ${req?.method ?? '?'} '
          '${req?.url.path ?? '?'}',
      keys: {'request_id': error.requestId ?? 'none'},
    );
  }

  /// Decodes a JSON object response. Every failure (non-2xx, malformed
  /// body) is an [ApiException]. Failures are debug-logged under [op] with
  /// status, `error_code` and request id only — never the body, which can
  /// carry signed URLs, identifiers or personal data.
  Map<String, dynamic> decodeMap(http.Response res, {required String op}) {
    throwIfAuthExpired(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = ApiException.fromResponse(res);
      debugLog(
        'decodeMap: $op failed (${error.statusCode}) '
        'error_code=${error.errorCode} request_id=${error.requestId}',
      );
      throw error;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (e) {
      debugLog(
        'decodeMap: $op returned invalid JSON '
        '(${res.statusCode}, ${res.bodyBytes.length} bytes)',
      );
      throw ApiException(
        statusCode: res.statusCode,
        message: 'Invalid response',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      debugLog(
        'decodeMap: $op returned a non-object JSON body '
        '(${decoded.runtimeType})',
      );
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

  /// Idempotent DELETE: `404` (already gone) counts as success — only with
  /// [goneErrorCode] as its `error_code`, when given. Other failures go
  /// through [errorDecode] ([decodeMap] by default).
  Future<void> deleteIdempotent(
    Uri uri, {
    required String op,
    String? goneErrorCode,
    Duration timeout = const Duration(seconds: 15),
    Map<String, dynamic> Function(http.Response res, {required String op})?
    errorDecode,
  }) async {
    final res = await withAuth(
      (token) => http.delete(uri, headers: authHeaders(token)).timeout(timeout),
    );
    throwIfAuthExpired(res);
    if (res.statusCode == 404 &&
        (goneErrorCode == null ||
            ApiException.fromResponse(res).errorCode == goneErrorCode)) {
      return;
    }
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

/// A request or token refresh outlived the session that started it (signed
/// out, or another account signed in). Not an [AuthExpiredException]: the
/// current session is fine and must not be signed out over it.
class SessionChangedException implements Exception {
  @override
  String toString() => 'The session that sent this request has ended';
}

class _RefreshFlight {
  _RefreshFlight(this.epoch);
  final int epoch;
  late final Future<({String accessToken, String refreshToken})> future;
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
