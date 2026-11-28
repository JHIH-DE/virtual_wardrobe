import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// A failed backend call: the envelope's `error_code` and `message` (the
/// CMS is an internal tool, so the backend's message is shown as-is).
class ApiError implements Exception {
  final int statusCode;
  final String? errorCode;
  final String message;

  /// The backend's `x-request-id`, to quote when reporting a server error.
  final String? requestId;

  const ApiError(
    this.statusCode,
    this.errorCode,
    this.message, {
    this.requestId,
  });

  @override
  String toString() => message;
}

/// The session's tokens live in memory only: reloading the page signs in
/// again through Google, so no admin token sits in browser storage.
class ApiClient extends ChangeNotifier {
  static const _timeout = Duration(seconds: 30);

  final http.Client _http;
  String? _accessToken;
  String? _refreshToken;
  bool _confirmed = false;
  int? _userId;
  String? _signOutReason;
  Future<bool>? _refreshing;

  ApiClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// Signed in and confirmed as an admin.
  bool get isSignedIn => _confirmed && _accessToken != null;

  /// The signed-in admin's user id.
  int? get userId => _userId;

  /// Why the session ended on its own (e.g. admin rights removed), for the
  /// login page; cleared when read.
  String? takeSignOutReason() {
    final reason = _signOutReason;
    _signOutReason = null;
    return reason;
  }

  /// Gets backend tokens; the session only counts as signed in once the
  /// caller has checked the account and calls [confirmSession].
  Future<void> signInWithGoogle(String idToken) async {
    final data = await _send(
      'POST',
      '/auth/google',
      body: {'id_token': idToken},
      auth: false,
    );
    _setTokens(data as Map<String, dynamic>);
  }

  void confirmSession(int userId) {
    _confirmed = true;
    _userId = userId;
    _signOutReason = null;
    notifyListeners();
  }

  void signOut() {
    final refresh = _refreshToken;
    _accessToken = null;
    _refreshToken = null;
    _confirmed = false;
    _userId = null;
    notifyListeners();
    if (refresh != null) {
      // Best effort: the session is already gone locally.
      unawaited(
        _http
            .post(
              Uri.parse('${Config.apiUrl}/auth/logout'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': refresh}),
            )
            .timeout(_timeout)
            .then<void>((_) {}, onError: (_) {}),
      );
    }
  }

  /// A query value is a String, or an Iterable of them to repeat the key.
  Future<dynamic> get(String path, {Map<String, Object>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);
  Future<dynamic> put(String path, Object body) =>
      _send('PUT', path, body: body);
  Future<dynamic> patch(String path, Object body) =>
      _send('PATCH', path, body: body);

  /// A POST the backend deduplicates by [idempotencyKey]: a resend after a
  /// timeout must reuse the same key.
  Future<dynamic> postIdempotent(
    String path,
    Object body, {
    required String idempotencyKey,
  }) => _send(
    'POST',
    path,
    body: body,
    headers: {'Idempotency-Key': idempotencyKey},
  );
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// PUT raw bytes to a GCS signed upload URL (outside the API envelope).
  Future<void> putToSignedUrl(
    String url,
    Uint8List bytes,
    String contentType,
  ) async {
    final res = await _http
        .put(
          Uri.parse(url),
          headers: {'Content-Type': contentType},
          body: bytes,
        )
        .timeout(const Duration(minutes: 2));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiError(res.statusCode, null, '圖片上傳失敗（HTTP ${res.statusCode}）');
    }
  }

  void _setTokens(Map<String, dynamic> data) {
    _accessToken = data['access_token'] as String?;
    _refreshToken = data['refresh_token'] as String?;
    notifyListeners();
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object>? query,
    Map<String, String>? headers,
    bool auth = true,
  }) async {
    Future<http.Response> request() => _request(
      method,
      path,
      body: body,
      query: query,
      headers: headers,
      auth: auth,
    );
    var res = await request();
    if (res.statusCode == 401 && auth && await _refresh()) {
      res = await request();
    }
    if (res.statusCode == 401 && auth) {
      signOut();
    }
    try {
      return _decode(res);
    } on ApiError catch (e) {
      if (auth && _confirmed && e.errorCode == 'ADMIN_REQUIRED') {
        _signOutReason = e.message;
        signOut();
      }
      rethrow;
    }
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
    Map<String, Object>? query,
    Map<String, String>? headers,
    required bool auth,
  }) {
    final uri = Uri.parse(
      '${Config.apiUrl}$path',
    ).replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json';
    if (headers != null) request.headers.addAll(headers);
    if (auth && _accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (body != null) request.body = jsonEncode(body);
    return _http.send(request).then(http.Response.fromStream).timeout(_timeout);
  }

  /// Refresh tokens rotate (single use), so concurrent 401s share one refresh,
  /// and a refresh with an unknown outcome is never resent: the session ends.
  Future<bool> _refresh() {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return Future.value(false);
    return _refreshing ??= () async {
      try {
        final res = await _http
            .post(
              Uri.parse('${Config.apiUrl}/auth/refresh'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': refreshToken}),
            )
            .timeout(_timeout);
        if (res.statusCode != 200) return false;
        _setTokens(
          (jsonDecode(res.body) as Map<String, dynamic>)['data']
              as Map<String, dynamic>,
        );
        return true;
      } catch (_) {
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  dynamic _decode(http.Response res) {
    Map<String, dynamic>? envelope;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) envelope = decoded;
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300 && envelope != null) {
      return envelope['data'];
    }
    final detail = envelope?['detail'];
    throw ApiError(
      res.statusCode,
      envelope?['error_code'] as String?,
      envelope?['message'] as String? ??
          (detail is List && detail.isNotEmpty
              ? '欄位格式不正確：${_describe(detail)}'
              : null) ??
          '伺服器錯誤（HTTP ${res.statusCode}）',
      requestId: res.headers['x-request-id'],
    );
  }

  /// FastAPI's 422 `detail`: which field failed and why.
  static String _describe(List<dynamic> detail) => detail
      .whereType<Map<String, dynamic>>()
      .map(
        (e) =>
            '${(e['loc'] as List?)?.skip(1).join('.') ?? ''} ${e['msg'] ?? ''}'
                .trim(),
      )
      .join('；');
}
