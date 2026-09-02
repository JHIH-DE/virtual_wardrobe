import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

class AuthService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/auth';

  /// One unauthenticated JSON POST against `/auth`, time-bounded so a login
  /// or refresh can't hang the sign-in flow forever.
  Future<http.Response> _postJson(String path, Map<String, dynamic> body) {
    return http
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
  }

  /// Pulls the issued `access_token`/`refresh_token` pair out of a decoded
  /// response envelope, throwing a clear [label]-prefixed error if either is
  /// missing or blank.
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
      decodeMap(res, op: 'loginWithGoogle'),
      label: 'Google login',
    );
  }

  Future<({String accessToken, String refreshToken})> loginWithAppleIdToken(
    String idToken,
  ) async {
    debugLog('--- loginWithAppleIdToken ---');
    final res = await _postJson('/apple', {'id_token': idToken});
    return _tokenPair(
      decodeMap(res, op: 'loginWithApple'),
      label: 'Apple login',
    );
  }

  Future<({String accessToken, String refreshToken})> loginWithFacebookIdToken(
    String idToken,
  ) async {
    debugLog('--- loginWithFacebook ---');
    final res = await _postJson('/facebook', {'id_token': idToken});
    return _tokenPair(
      decodeMap(res, op: 'loginWithFacebook'),
      label: 'Facebook login',
    );
  }

  Future<void> logout(String refreshToken) async {
    debugLog('--- logout ---');
    // Best-effort: local tokens are cleared by the caller regardless of the
    // server's response, so this deliberately doesn't check the status.
    await _postJson('/logout', {'refresh_token': refreshToken});
  }

  Future<({String accessToken, String refreshToken})> refreshAccessToken(
    String refreshToken,
  ) async {
    debugLog('--- refreshAccessToken ---');
    final res = await _postJson('/refresh', {'refresh_token': refreshToken});
    return _tokenPair(
      decodeMap(res, op: 'refreshAccessToken'),
      label: 'Token refresh',
    );
  }
}
