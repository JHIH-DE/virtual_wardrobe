import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../../data/look_category.dart';
import 'base_service.dart';

class OutfitService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/outfits';

  Future<Map<String, dynamic>> createOutfit(
      {
        required List<int> garmentIds
      }) async {
    final token = await getSafeToken();
    final uri = Uri.parse(_baseUrl);

    final payload = <String, dynamic>{
      'garment_ids': garmentIds,
      "style": "Minimal",
    };

    final res = await http.post(
      uri,
      headers: authHeaders(token),
      body: jsonEncode(payload),
    );

    final envelope = decodeMap(res, op: 'createOutfit');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

  Future<List<Look>> getOutfits() async {
    final token = await getSafeToken();
    final uri = Uri.parse(_baseUrl);
    final res = await http.get(uri, headers: authHeaders(token));

    final envelope = decodeMap(res, op: 'getOutfits');
    final data = envelope['data'];
    if (data is! List) throw Exception('getOutfits: response missing list data');

    return data.whereType<Map<String, dynamic>>().map((j) => Look.fromJson(j)).toList();
  }

  Future<void> deleteOutfit(int jobId) async {
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/$jobId');
    final res = await http.delete(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404) return;
    throw Exception('deleteOutfit failed (${res.statusCode})');
  }

  Future<Map<String, dynamic>> getOutfit(int jobId) async {
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/$jobId');
    final res = await http.get(uri, headers: authHeaders(token));
    final envelope = decodeMap(res, op: 'getOutfit');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }
}