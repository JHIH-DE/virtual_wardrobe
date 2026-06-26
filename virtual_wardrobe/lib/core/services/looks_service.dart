import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../../data/look.dart';
import 'base_service.dart';

class LookService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/looks';

  Future<Map<String, dynamic>> createLook({required List<int> garmentIds, required String type}) async {
    debugPrint('createLook garmentIds: $garmentIds');
    final token = await getSafeToken();
    final uri = Uri.parse(_baseUrl);
    final payload = <String, dynamic>{
      'garment_ids': garmentIds,
      "job_type": type,
      "style": "Minimal",
    };
    final res = await http.post(uri, headers: authHeaders(token), body: jsonEncode(payload));
    throwIfAuthExpired(res);
    final envelope = decodeMap(res, op: 'createLook');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

  Future<List<Look>> getAllLooks() async {
    debugPrint('--- getAllLooks ---');
    final token = await getSafeToken();
    final uri = Uri.parse(_baseUrl);
    final res = await http.get(uri, headers: authHeaders(token));
    throwIfAuthExpired(res);
    final envelope = decodeMap(res, op: 'getAllLooks');
    final data = envelope['data'];
    if (data is! List) throw Exception('getAllLooks: response missing list data');

    return data.whereType<Map<String, dynamic>>().map((j) => Look.fromJson(j)).toList();
  }

  Future<Map<String, dynamic>> getLook(int jobId) async {
    debugPrint('--- getLook ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/$jobId');
    final res = await http.get(uri, headers: authHeaders(token));
    throwIfAuthExpired(res);
    final envelope = decodeMap(res, op: 'getLook');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('getLook: response missing outfit data object');
    }
    return data;
  }

  Future<void> deleteLook(int jobId) async {
    debugPrint('--- deleteLook ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/$jobId');
    final res = await http.delete(uri, headers: authHeaders(token));
    throwIfAuthExpired(res);

    if (res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404) {
      return;
    }
    throw Exception('deleteLook failed (${res.statusCode}): ${res.body}');
  }
}