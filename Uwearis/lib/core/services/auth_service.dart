import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'api_exception.dart';
import 'base_service.dart';

class AuthService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/auth';

  /// Unauthenticated, time-bounded POST to `/auth`.
  Future<http.Response> _postJson(String path, Map<String, dynamic> body) {
    return sendTimed(
      () => http
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15)),
    );
  }

  /// A 401 from a login endpoint means the provider token was rejected, not
  /// that a session expired — [decodeMap] would raise AuthExpiredException.
  Map<String, dynamic> _decodeLogin(http.Response res, {required String op}) {
    if (res.statusCode == 401) {
      final rejected = ApiException.fromResponse(res);
      debugLog('$op rejected: 401 error_code=${rejected.errorCode}');
      throw rejected;
    }
    return decodeMap(res, op: op);
  }

  ({String accessToken, String refreshToken}) _tokenPair(
    Map<String, dynamic> envelope, {
    required String label,
  }) {
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('$label: response missing data');

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('$label: missing access_token');
    }
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('$label: missing refresh_token');
    }
    return (accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<({String accessToken, String refreshToken})> loginWithGoogleIdToken(
    String idToken,
  ) async {
    debugLog('--- loginWithGoogleIdToken ---');
    final res = await _postJson('/google', {'id_token': idToken});
    return _tokenPair(
      _decodeLogin(res, op: 'loginWithGoogle'),
      label: 'Google login',
    );
  }

  /// [name]: Apple only provides it on the first authorization, so omit it
  /// on repeat logins rather than sending an empty string.
  Future<({String accessToken, String refreshToken})> loginWithAppleIdToken(
    String idToken, {
    String? name,
  }) async {
    debugLog('--- loginWithAppleIdToken ---');
    final res = await _postJson('/apple', {
      'id_token': idToken,
      if (name != null && name.isNotEmpty) 'name': name,
    });
    return _tokenPair(
      _decodeLogin(res, op: 'loginWithApple'),
      label: 'Apple login',
    );
  }

  /// Facebook gives an access token, not an id token, hence the
  /// `access_token` body key.
  Future<({String accessToken, String refreshToken})>
  loginWithFacebookAccessToken(String accessToken) async {
    debugLog('--- loginWithFacebookAccessToken ---');
    final res = await _postJson('/facebook', {'access_token': accessToken});
    return _tokenPair(
      _decodeLogin(res, op: 'loginWithFacebook'),
      label: 'Facebook login',
    );
  }

  Future<void> logout(String refreshToken) async {
    debugLog('--- logout ---');
    // Best-effort: the caller clears local tokens regardless of status.
    await _postJson('/logout', {'refresh_token': refreshToken});
  }
}
