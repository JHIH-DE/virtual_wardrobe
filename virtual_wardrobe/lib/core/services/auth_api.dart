import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import '../../features/garment_category.dart';
import '../../features/login_page.dart';
import 'token_storage.dart';

class AuthApi {
  static const String baseUrl = 'http://10.0.2.2:8000';

  static Future<String> loginWithGoogleIdToken(String idToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/auth/google');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );

    final envelope = _decodeMap(res, op: 'loginWithGoogle');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Google login: response missing data');

    final token = data['access_token'] as String?;
    if (token == null || token.isEmpty) throw Exception('Google login: missing access_token');
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
      body: jsonEncode({'content_type': 'image/jpeg'}),
    );

    final envelope = _decodeMap(res, op: 'initUpload');
    final data = envelope['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('initUpload: invalid response json');
    }

    return InitUploadResult.fromJson(data);
  }

  static Future<void> uploadImage(String uploadUrl, String localPath) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    final uri = Uri.parse(uploadUrl);
    final res = await http.put(uri, headers: {'Content-Type': 'image/jpeg'}, body: bytes);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PUT to signed url failed: ${res.statusCode} ${res.body}');
    }
  }

  static Future<Garment> completeUpload(String accessToken, Garment garment) async {
    final uri = Uri.parse('$baseUrl/api/v1/garments/complete');
    
    final String? dateStr = garment.purchaseDate?.toIso8601String().split('T')[0];

    final payload = <String, dynamic>{
      'name': garment.name,
      'category': garment.category.apiValue,
      'sub_category': garment.subCategory,
      'object_name': garment.objectName,
      'brand': garment.brand,
      'color': garment.color,
      'price': garment.price,
      'purchase_date': dateStr,
    };

    final res = await http.post(
      uri,
      headers: authHeaders(accessToken),
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    final envelope = _decodeMap(res, op: 'completeUpload');
    final data = envelope['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('completeUpload: response missing data');
    }
    return Garment.fromJson(data);
  }

  static Future<List<Garment>> getGarments(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/garments');
    final res = await http.get(uri, headers: authHeaders(accessToken));

    final envelope = _decodeMap(res, op: 'getGarments');
    final data = envelope['data'];
    if (data is! List) throw Exception('getGarments: response missing list data');

    return data.whereType<Map<String, dynamic>>().map((j) => Garment.fromJson(j)).toList();
  }

  static Future<void> deleteGarment(String accessToken, int garmentId) async {
    final uri = Uri.parse('$baseUrl/api/v1/garments/$garmentId');
    final res = await http.delete(uri, headers: {'Authorization': 'Bearer $accessToken'});
    if (res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404) return;
    throw Exception('deleteGarment failed (${res.statusCode})');
  }

  static Future<Garment> updateGarment(String accessToken, Garment garment) async {
    if (garment.id == null) throw Exception('updateGarment: missing id');
    final uri = Uri.parse('$baseUrl/api/v1/garments/${garment.id}');
    final res = await http.patch(uri, headers: authHeaders(accessToken), body: jsonEncode(garment.toJson()));
    final envelope = _decodeMap(res, op: 'updateGarment');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('updateGarment: response missing data');

    return Garment.fromJson(data);
  }

  // --- Try-On flow ---

  static Future<Map<String, dynamic>> createTryOnJob(
    String accessToken, {
    required List<int> garmentIds
  }) async {
    print('Creating Try-On Job with garment IDs: $garmentIds');
    final uri = Uri.parse('$baseUrl/api/v1/tryon/jobs');
    
    final payload = <String, dynamic>{
      'garment_ids': garmentIds,
      "occasion": "Casual",
      "style": "Minimal",
    };

    final res = await http.post(
      uri,
      headers: authHeaders(accessToken),
      body: jsonEncode(payload),
    );

    final envelope = _decodeMap(res, op: 'createTryOnJob');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

  static Future<Map<String, dynamic>> getTryOnJobStatus(String accessToken, String jobId) async {
    final uri = Uri.parse('$baseUrl/api/v1/tryon/jobs/$jobId');
    final res = await http.get(uri, headers: authHeaders(accessToken));
    final envelope = _decodeMap(res, op: 'getTryOnJobStatus');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

  // --- Analyze Instant ---
  static Future<Map<String, dynamic>> analyzeInstantGarment(String accessToken, String localPath) async {
    final uri = Uri.parse('$baseUrl/api/v1/garments/analyze-instant');
    final request = http.MultipartRequest('POST', uri);
    
    request.headers.addAll({
      'Authorization': 'Bearer $accessToken',
    });

    final mimeType = lookupMimeType(localPath) ?? 'image/jpeg';
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      localPath,
      contentType: MediaType.parse(mimeType),
    ));

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);

    final envelope = _decodeMap(res, op: 'analyzeInstantGarment');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

  static Map<String, String> authHeaders(String accessToken) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  static void _throwIfAuthExpired(http.Response res) {
    if (res.statusCode == 401) throw AuthExpiredException();
  }

  static Map<String, dynamic> _decodeMap(http.Response res, {required String op}) {
    _throwIfAuthExpired(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$op failed (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) throw Exception('$op: invalid response');
    return data;
  }

  // --- Profile / Avatar flow ---
  /// Updated to return the inner 'data' map from the common response envelope
  static Future<Map<String, dynamic>> getMyProfile(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me');
    final res = await http.get(uri, headers: authHeaders(accessToken));
    final envelope = _decodeMap(res, op: 'getMyProfile');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

  static Future<InitUploadResult> avatarInitUpload(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me/avatar/init-upload');
    final res = await http.post(uri, headers: authHeaders(accessToken), body: jsonEncode({'content_type': 'image/jpeg'}));
    final envelope = _decodeMap(res, op: 'avatarInitUpload');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return InitUploadResult.fromJson(data);
  }

  static Future<String> avatarComplete(String accessToken, {required String objectName}) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me/avatar/complete');
    final res = await http.post(uri, headers: authHeaders(accessToken), body: jsonEncode({'object_name': objectName}));
    final envelope = _decodeMap(res, op: 'avatarComplete');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    final url = data['object_url']?.toString();
    if (url == null) throw Exception('avatarComplete: response missing object_url');
    return url;
  }

  static Future<String?> getMyAvatar(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me/avatar');
    final res = await http.get(uri, headers: authHeaders(accessToken));
    _throwIfAuthExpired(res);
    if (res.statusCode == 404) return null;
    final envelope = _decodeMap(res, op: 'getMyAvatar');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return data['object_url']?.toString();
  }

  // --- Full Body flow ---
  static Future<InitUploadResult> fullBodyInitUpload(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me/full-body/init-upload');
    final res = await http.post(uri, headers: authHeaders(accessToken), body: jsonEncode({'content_type': 'image/jpeg'}));
    final envelope = _decodeMap(res, op: 'fullBodyInitUpload');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return InitUploadResult.fromJson(data);
  }

  static Future<String> fullBodyComplete(String accessToken, {required String objectName}) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me/full-body/complete');
    final res = await http.post(uri, headers: authHeaders(accessToken), body: jsonEncode({'object_name': objectName}));
    final envelope = _decodeMap(res, op: 'fullBodyComplete');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    final url = data['object_url']?.toString();
    if (url == null) throw Exception('fullBodyComplete: response missing object_url');
    return url;
  }

  static Future<String?> getMyFullBody(String accessToken) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me/full-body');
    final res = await http.get(uri, headers: authHeaders(accessToken));
    _throwIfAuthExpired(res);
    if (res.statusCode == 404) return null;
    final envelope = _decodeMap(res, op: 'getMyFullBody');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return data['object_url']?.toString();
  }

  static Future<void> putJpegToSignedUrl(String uploadUrl, String localPath) async {
    final bytes = await File(localPath).readAsBytes();
    final res = await http.put(Uri.parse(uploadUrl), headers: {'Content-Type': 'image/jpeg'}, body: bytes);
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('PUT failed');
  }

  static Future<Map<String, dynamic>> updateMyProfile(
    String accessToken, {
    String? name,
    String? gender,
    String? birthday,
    num? height,
    num? weight,
    String? unitSystem,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/users/me');

    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (gender != null) payload['gender'] = gender;
    if (birthday != null) payload['birthday'] = birthday;
    if (height != null) payload['height'] = height;
    if (weight != null) payload['weight'] = weight;
    if (unitSystem != null) payload['unit_system'] = unitSystem;

    final res = await http.patch(
      uri,
      headers: authHeaders(accessToken),
      body: jsonEncode(payload),
    );

    final envelope = _decodeMap(res, op: 'updateMyProfile');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
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
  const InitUploadResult({required this.uploadUrl, required this.objectName, required this.publicUrl});

  factory InitUploadResult.fromJson(Map<String, dynamic> json) {
    return InitUploadResult(
      uploadUrl: json['upload_url'] ?? '',
      objectName: json['object_name'] ?? '',
      publicUrl: json['public_url'] ?? '',
    );
  }
}
