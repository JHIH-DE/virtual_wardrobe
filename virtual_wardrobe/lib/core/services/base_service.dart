import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'error_handler.dart';

mixin BaseService {

  Map<String, String> authHeaders(String accessToken) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
    };
  }

  Map<String, dynamic> decodeResponse(http.Response res, {required String op}) {
    if (res.statusCode == 401) {
      throw Exception('Authentication expired');
    }
    
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('$op failed (${res.statusCode}): ${res.body}');
    }
    
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('$op: invalid response format');
    }

    return (data['data'] as Map<String, dynamic>?) ?? data;
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
    final res = await http.put(Uri.parse(uploadUrl), headers: {'Content-Type': 'image/jpeg'}, body: bytes);
    if (res.statusCode < 200 || res.statusCode >= 300) throw Exception('PUT failed');
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