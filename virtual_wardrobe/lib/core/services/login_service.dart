import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'base_service.dart';

class LoginService with BaseService {

  Future<String> loginWithGoogleIdToken(String idToken) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/auth/google');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    final envelope = decodeMap(res, op: 'loginWithGoogle');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Google login: response missing data');

    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) throw Exception('Google login: missing access_token');
    return token;
  }
}