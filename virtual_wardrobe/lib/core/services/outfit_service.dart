import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../../data/look_category.dart';
import 'base_service.dart';

class OutfitService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/outfits';

  Future<Map<String, dynamic>> createOutfit({required List<int> garmentIds, required String type}) async {
    debugPrint('--- createOutfit ---');
    debugPrint('createOutfit garmentIds: $garmentIds');
    final token = await getSafeToken();
    final uri = Uri.parse(_baseUrl);
    final payload = <String, dynamic>{
      'garment_ids': garmentIds,
      "job_type": type,
      "style": "Minimal",
    };
    final res = await http.post(uri, headers: authHeaders(token), body: jsonEncode(payload));
    throwIfAuthExpired(res);
    final envelope = decodeMap(res, op: 'createOutfit');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

  Future<List<Look>> getAllOutfits() async {
    debugPrint('--- getAllOutfits ---');
    final token = await getSafeToken();
    final uri = Uri.parse(_baseUrl);
    final res = await http.get(uri, headers: authHeaders(token));
    throwIfAuthExpired(res);
    final envelope = decodeMap(res, op: 'getAllOutfits');
    final data = envelope['data'];
    if (data is! List) throw Exception('getAllOutfits: response missing list data');

    return data.whereType<Map<String, dynamic>>().map((j) => Look.fromJson(j)).toList();
  }

  Future<Map<String, dynamic>> getOutfit(int jobId) async {
    debugPrint('--- getOutfit ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/$jobId');
    final res = await http.get(uri, headers: authHeaders(token));
    throwIfAuthExpired(res);
    final envelope = decodeMap(res, op: 'getOutfit');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('getOutfit: response missing outfit data object');
    }
    return data;
  }

  Future<void> deleteOutfit(int jobId) async {
    debugPrint('--- deleteOutfit ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/$jobId');
    final res = await http.delete(uri, headers: authHeaders(token));
    throwIfAuthExpired(res);

    if (res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404) {
      return;
    }
    throw Exception('deleteOutfit failed (${res.statusCode}): ${res.body}');
  }
}