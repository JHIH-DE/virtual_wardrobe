import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'base_api.dart';

class TryOnService with BaseApi {
  Future<Map<String, dynamic>> createTryOnJob(
      String accessToken, {
        required List<int> garmentIds
      }) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/tryon/jobs');

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

    final envelope = decodeMap(res, op: 'createTryOnJob');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

  Future<Map<String, dynamic>> getTryOnJobStatus(String accessToken, String jobId) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/tryon/jobs/$jobId');
    final res = await http.get(uri, headers: authHeaders(accessToken));
    final envelope = decodeMap(res, op: 'getTryOnJobStatus');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }
}