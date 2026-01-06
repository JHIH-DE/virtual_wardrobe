import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../features/garment_category.dart';

class AuthApi {
  // TODO: 換成你的正式網址
  // iOS/Android 模擬器用 localhost 會有坑：
  // Android emulator: http://10.0.2.2:8000
  // iOS simulator: http://127.0.0.1:8000
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<String> loginWithEmail(String email, String password) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/login');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode != 200) {
      final msg = _tryReadMessage(res.body) ?? 'Login failed (${res.statusCode})';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) throw Exception('Missing access_token');
    return token;
  }

  static Future<String> loginWithGoogleIdToken(String idToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/google');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    if (res.statusCode != 200) {
      final msg = _tryReadMessage(res.body) ?? 'Google login failed (${res.statusCode})';
      throw Exception(msg);
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) throw Exception('Missing access_token');
    return token;
  }

  static Future<InitUploadResult> initUpload(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/garments/init-upload');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'category': 'top',
        'content_type': 'image/jpeg',
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('initUpload failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('initUpload: invalid response json: ${res.body}');
    }

    return InitUploadResult.fromJson(data);
  }

  static Future<void> uploadImage(String uploadUrl, String localPath) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();

    final uri = Uri.parse(uploadUrl);

    final res = await http.put(
      uri,
      headers: {
        'Content-Type': 'image/jpeg',
      },
      body: bytes,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PUT to signed url failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<Garment> completeUpload(String accessToken, Garment garment) async {
    final uri = Uri.parse('$baseUrl/api/v1/garments/complete');

    final payload = <String, dynamic>{
      'name': garment.name,
      'category': garment.category.apiValue,
      'object_name': garment.objectName,
      'season': garment.season?.apiValue,
      'brand': garment.brand,
      'color': garment.color,
      'price': garment.price,
      'purchase_date': garment.purchaseDate?.toIso8601String(),
    };

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception(
        'completeUpload failed (${res.statusCode}): ${res.body}',
      );
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception(
        'completeUpload: invalid response json: ${res.body}',
      );
    }

    final id = data['id'];
    if (id == null) {
      throw Exception(
        'completeUpload: missing id in response: ${res.body}',
      );
    }

    return garment.copyWith(id: id);
  }

  static Future<List<Garment>> getGarments(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/garments');
    final res = await http.get(uri, headers: authHeaders(accessToken));

    if (res.statusCode != 200) {
      throw Exception('getGarments failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! List) {
      throw Exception('getGarments: invalid response json: ${res.body}');
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map((j) => Garment.fromJson(j))
        .toList();
  }

  static Future<void> deleteGarment(String accessToken, int garmentId) async {
    final uri = Uri.parse('$baseUrl/api/v1/garments/$garmentId');

    final res = await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (res.statusCode == 200 || res.statusCode == 204) return;
    if (res.statusCode == 404) return;

    throw Exception('deleteGarment failed (${res.statusCode}): ${res.body}');
  }

  static Future<Garment> updateGarment(String accessToken, Garment garment) async {
    if (garment.id == null) {
      throw Exception('updateGarment: missing garment.id');
    }

    // 你的 Postman 看到有 PATCH Update，這邊假設是 /api/v1/garments/{id}
    final uri = Uri.parse('$baseUrl/api/v1/garments/${garment.id}');
    final res = await http.patch(
      uri,
      headers: authHeaders(accessToken),
      body: jsonEncode(garment.toJson()),
    );

    if (res.statusCode != 200) {
      throw Exception('updateGarment failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('updateGarment: invalid response json: ${res.body}');
    }
    return Garment.fromJson(data);
  }

  static Map<String, String> authHeaders(String accessToken) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  static String? _tryReadMessage(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map<String, dynamic>) {
        return (j['detail'] ?? j['message'])?.toString();
      }
    } catch (_) {}
    return null;
  }
}

class InitUploadResult {
  final String uploadUrl;
  final String objectName;
  final String publicUrl;

  const InitUploadResult({
    required this.uploadUrl,
    required this.objectName,
    required this.publicUrl,
  });

  factory InitUploadResult.fromJson(Map<String, dynamic> json) {
    final uploadUrl = (json['upload_url'] as String?)?.trim();
    final objectName = (json['object_name'] as String?)?.trim();
    final publicUrl = (json['public_url'] as String?)?.trim();

    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw FormatException('Missing upload_url');
    }
    if (objectName == null || objectName.isEmpty) {
      throw FormatException('Missing object_name');
    }
    if (publicUrl == null || publicUrl.isEmpty) {
      throw FormatException('Missing public_url');
    }

    return InitUploadResult(
      uploadUrl: uploadUrl,
      objectName: objectName,
      publicUrl: publicUrl,
    );
  }
}