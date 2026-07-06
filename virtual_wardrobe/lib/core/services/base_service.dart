import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
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

  /// Makes an authenticated request. On 401, silently refreshes tokens and retries once.
  /// Throws [AuthExpiredException] if refresh fails or no refresh token is stored.
  Future<http.Response> withAuth(
    Future<http.Response> Function(String token) request,
  ) async {
    final token = await getSafeToken();
    final res = await request(token);
    if (res.statusCode != 401) return res;

    final storedRefresh = await AuthStorage.getRefreshToken();
    if (storedRefresh == null) throw AuthExpiredException();

    try {
      final refreshRes = await http.post(
        Uri.parse('${AppConfig.fullApiUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': storedRefresh}),
      );
      if (refreshRes.statusCode != 200) throw AuthExpiredException();

      final body = jsonDecode(refreshRes.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final newAccessToken = data?['access_token'] as String?;
      final newRefreshToken = data?['refresh_token'] as String?;
      if (newAccessToken == null || newRefreshToken == null) {
        throw AuthExpiredException();
      }

      await AuthStorage.saveAccessToken(newAccessToken);
      await AuthStorage.saveRefreshToken(newRefreshToken);
      return await request(newAccessToken);
    } catch (e) {
      if (e is AuthExpiredException) rethrow;
      throw AuthExpiredException();
    }
  }

  Map<String, dynamic> decodeMap(http.Response res, {required String op}) {
    throwIfAuthExpired(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$op failed (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) throw Exception('$op: invalid response');
    return data;
  }

  void throwIfAuthExpired(http.Response res) {
    if (res.statusCode == 401) throw AuthExpiredException();
  }

  Future<void> putJpegToSignedUrl(String uploadUrl, String localPath) async {
    final bytes = await File(localPath).readAsBytes();
    final res = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': 'image/jpeg'},
      body: bytes,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PUT failed');
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
