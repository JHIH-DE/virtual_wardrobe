import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../features/garment_category.dart';
import '../../features/login_page.dart';
import 'token_storage.dart';

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
    final uri = Uri.parse('$baseUrl/api/v1/garment/init-upload');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
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
    final uri = Uri.parse('$baseUrl/api/v1/garment/complete');
    final payload = <String, dynamic>{
      'category': garment.category.apiValue,
      'name': garment.name,
      'object_name': garment.objectName,
      'brand': garment.brand,
      'color': garment.color,
      'season': garment.season.apiValue,
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
      throw Exception('completeUpload failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('completeUpload: invalid response json: ${res.body}');
    }

    return Garment.fromJson(data);
  }

  static Future<List<Garment>> getGarments(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/garment');
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
    final uri = Uri.parse('$baseUrl/api/v1/garment/$garmentId');

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

    final uri = Uri.parse('$baseUrl/api/v1/garment/${garment.id}');
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

  static void _throwIfAuthExpired(http.Response res) {
    if (res.statusCode == 401) {
      throw AuthExpiredException();
    }
  }

  static Map<String, dynamic> _decodeMap(http.Response res, {required String op}) {
    _throwIfAuthExpired(res);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$op failed (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('$op: invalid response json: ${res.body}');
    }
    return data;
  }

  // --- Avatar flow (Profile) ---

  static Future<InitUploadResult> avatarInitUpload(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/profile/avatar/init-upload');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
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

  static Future<String> avatarComplete(String accessToken, {required String objectName}) async {
    final uri = Uri.parse('$baseUrl/api/v1/profile/avatar/complete');
    final res = await http.post(
      uri,
      headers: authHeaders(accessToken),
      body: jsonEncode({'object_name': objectName}),
    );
    final data = _decodeMap(res, op: 'avatarComplete');
    // 你 swagger 顯示 response "string"，我這邊用 body string 也行：
    // 如果後端真的回 JSON string (e.g. "https://..."), 就這樣取：
    return data['url']?.toString() ?? res.body.replaceAll('"', '');
  }

  static Future<String?> getMyAvatar(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/profile/me/avatar');
    final res = await http.get(uri, headers: authHeaders(accessToken));
    _throwIfAuthExpired(res);

    if (res.statusCode == 404) return null; // 沒頭像
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('getMyAvatar failed (${res.statusCode}): ${res.body}');
    }

    // swagger 顯示 response "string"
    return res.body.replaceAll('"', '');
  }

  static Future<void> deleteMyAvatar(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/profile/avatar');
    final res = await http.delete(uri, headers: authHeaders(accessToken));
    _throwIfAuthExpired(res);

    if (res.statusCode == 204) return;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('deleteMyAvatar failed (${res.statusCode}): ${res.body}');
    }
  }

  // Signed URL PUT (通用)
  static Future<void> putJpegToSignedUrl(String uploadUrl, String localPath) async {
    final bytes = await File(localPath).readAsBytes();
    final res = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': 'image/jpeg'},
      body: bytes,
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      // signed url 過期通常是 403
      throw Exception('PUT signed url failed (${res.statusCode}): ${res.body}');
    }
  }

  Future<String> getAccessToken() async {
    final token = await TokenStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('Not logged in. Please log in again.');
    }
    return token;
  }

  // --- Profile update ---
  static Future<Map<String, dynamic>> updateMyProfile(
      String accessToken, {
        int? height,
        double? weight,
        int? age,
        String? name,
        String? pictureUrl,
      }) async {
    final uri = Uri.parse('$baseUrl/api/v1/user/me');

    final payload = <String, dynamic>{};
    if (height != null) payload['height_cm'] = height;
    if (weight != null) payload['weight_kg'] = weight;
    if (age != null) payload['age'] = age;
    if (name != null) payload['name'] = name;
    if (pictureUrl != null) payload['picture_url'] = pictureUrl;

    final res = await http.patch(
      uri,
      headers: authHeaders(accessToken),
      body: jsonEncode(payload),
    );

    return _decodeMap(res, op: 'updateMyProfile');
  }
}

class AuthExpiredException implements Exception {
  final String message;
  AuthExpiredException([this.message = 'Authentication expired']);
  @override
  String toString() => message;
}

class AuthExpiredHandler {
  static Future<void> handle(BuildContext context) async {
    await TokenStorage.clear();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Your session has expired. Please log in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
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