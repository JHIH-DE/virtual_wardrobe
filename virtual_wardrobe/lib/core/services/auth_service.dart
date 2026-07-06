import 'dart:async';
import 'dart:convert';

import '../utils/debug_log.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'base_service.dart';

class AuthService with BaseService {

  Future<({String accessToken, String refreshToken})> loginWithGoogleIdToken(String idToken) async {
    debugLog('--- loginWithGoogleIdToken ---');
    final uri = Uri.parse('${AppConfig.fullApiUrl}/auth/google');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    final envelope = decodeMap(res, op: 'loginWithGoogle');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Google login: response missing data');

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) throw Exception('Google login: missing access_token');
    if (refreshToken == null || refreshToken.isEmpty) throw Exception('Google login: missing refresh_token');
    return (accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<({String accessToken, String refreshToken})> loginWithAppleIdToken(String idToken) async {
    debugLog('--- loginWithAppleIdToken ---');
    final uri = Uri.parse('${AppConfig.fullApiUrl}/auth/apple');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    final envelope = decodeMap(res, op: 'loginWithApple');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Apple login: response missing data');

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) throw Exception('Apple login: missing access_token');
    if (refreshToken == null || refreshToken.isEmpty) throw Exception('Apple login: missing refresh_token');
    return (accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<({String accessToken, String refreshToken})> loginWithFaceBookIdToken(String idToken) async {
    debugLog('--- loginWithFaceBookIdToken ---');
    final uri = Uri.parse('${AppConfig.fullApiUrl}/auth/facebook');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    final envelope = decodeMap(res, op: 'loginWithFacebook');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Facebook login: response missing data');

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) throw Exception('Facebook login: missing access_token');
    if (refreshToken == null || refreshToken.isEmpty) throw Exception('Facebook login: missing refresh_token');
    return (accessToken: accessToken, refreshToken: refreshToken);
  }

  Future<void> logout(String refreshToken) async {
    debugLog('--- logout ---');
    final uri = Uri.parse('${AppConfig.fullApiUrl}/auth/logout');
    await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );
  }

  Future<({String accessToken, String refreshToken})> refreshAccessToken(String refreshToken) async {
    debugLog('--- refreshAccessToken ---');
    final uri = Uri.parse('${AppConfig.fullApiUrl}/auth/refresh');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    final envelope = decodeMap(res, op: 'refreshAccessToken');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Token refresh: response missing data');

    final accessToken = data['access_token'] as String?;
    final newRefreshToken = data['refresh_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) throw Exception('Token refresh: missing access_token');
    if (newRefreshToken == null || newRefreshToken.isEmpty) throw Exception('Token refresh: missing refresh_token');

    return (accessToken: accessToken, refreshToken: newRefreshToken);
  }
}