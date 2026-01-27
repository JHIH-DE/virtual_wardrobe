import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../../data/look_category.dart';
import 'base_service.dart';

class TryOnService with BaseService {

  Future<Map<String, dynamic>> createTryOnJob(
      String accessToken, {
        required List<int> garmentIds
      }) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/tryon/jobs');

    final payload = <String, dynamic>{
      'garment_ids': garmentIds,
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

  Future<List<Look>> getTryOnJobs(String accessToken) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/tryon/jobs');
    final res = await http.get(uri, headers: authHeaders(accessToken));

    final envelope = decodeMap(res, op: 'getTryOnJobs');
    final data = envelope['data'];
    if (data is! List) throw Exception('getTryOnJobs: response missing list data');

    return data.whereType<Map<String, dynamic>>().map((j) => Look.fromJson(j)).toList();
  }

  Future<void> deleteTryOnJob(String accessToken, int jobId) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/tryon/jobs/$jobId');
    final res = await http.delete(uri, headers: {'Authorization': 'Bearer $accessToken'});
    if (res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404) return;
    throw Exception('deleteTryOnJob failed (${res.statusCode})');
  }

  Future<Map<String, dynamic>> getTryOnJobStatus(String accessToken, int jobId) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/tryon/jobs/$jobId');
    final res = await http.get(uri, headers: authHeaders(accessToken));
    final envelope = decodeMap(res, op: 'getTryOnJobStatus');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }
}