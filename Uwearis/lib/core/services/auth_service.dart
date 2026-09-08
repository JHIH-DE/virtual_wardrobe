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

  /// [name] is the user's display name — only pass it on the *first* Apple
  /// authorization: Apple hands it to the client exactly once, in
  /// `AuthorizationCredentialAppleID.givenName`/`familyName`, and never
  /// again on subsequent sign-ins with the same Apple ID. The backend only
  /// has anywhere to put it on that same first request (it can't ask Apple
  /// for it later), so omit this argument entirely on repeat logins rather
  /// than send an empty string.
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
      decodeMap(res, op: 'loginWithApple'),
      label: 'Apple login',
    );
  }

  /// Facebook Login hands the client an *access token*, not an id token
  /// (unlike Google/Apple) — the backend verifies it against the Graph API
  /// itself, so this is the one provider whose request body key is
  /// `access_token`.
  Future<({String accessToken, String refreshToken})>
  loginWithFacebookAccessToken(String accessToken) async {
    debugLog('--- loginWithFacebookAccessToken ---');
    final res = await _postJson('/facebook', {'access_token': accessToken});
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
