import 'dart:async';
import 'dart:convert';

import '../utils/debug_log.dart';
import 'package:http/http.dart' as http;

import '../../data/look.dart';
import '../config/app_config.dart';
import 'base_service.dart';

class LookService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/looks';

  Future<Map<String, dynamic>> createLook({required List<int> garmentIds, required String type}) async {
    debugLog('--- createLook garmentIds: $garmentIds ---');
    final uri = Uri.parse(_baseUrl);
    final payload = <String, dynamic>{
      'garment_ids': garmentIds,
      "job_type": type,
      "style": "Minimal",
    };
    final res = await withAuth((token) => http.post(uri, headers: authHeaders(token), body: jsonEncode(payload)));
    final envelope = decodeMap(res, op: 'createLook');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

  Future<List<Look>> getAllLooks() async {
    debugLog('--- getAllLooks ---');
    final uri = Uri.parse(_baseUrl);
    final res = await withAuth((token) => http.get(uri, headers: authHeaders(token)));
    final envelope = decodeMap(res, op: 'getAllLooks');
    final data = envelope['data'];
    if (data is! List) throw Exception('getAllLooks: response missing list data');

    return data.whereType<Map<String, dynamic>>().map((j) => Look.fromJson(j)).toList();
  }

  Future<Map<String, dynamic>> getLook(int jobId) async {
    debugLog('--- getLook ---');
    final uri = Uri.parse('$_baseUrl/$jobId');
    final res = await withAuth((token) => http.get(uri, headers: authHeaders(token)));
    final envelope = decodeMap(res, op: 'getLook');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('getLook: response missing outfit data object');
    }
    return data;
  }

  Future<void> setFavorite(int lookId, {required bool isFavorite}) async {
    debugLog('--- setFavorite: $lookId / $isFavorite ---');
    final uri = Uri.parse('$_baseUrl/$lookId');
    final res = await withAuth((token) => http.patch(uri, headers: authHeaders(token), body: jsonEncode({'is_favorite': isFavorite})));
    decodeMap(res, op: 'setFavorite');
  }

  Future<void> setName(int lookId, {required String name}) async {
    debugLog('--- setName: $lookId / $name ---');
    final uri = Uri.parse('$_baseUrl/$lookId');
    final res = await withAuth((token) => http.patch(uri, headers: authHeaders(token), body: jsonEncode({'name': name})));
    decodeMap(res, op: 'setName');
  }

  Future<void> setSaved(int lookId, {required bool isSaved}) async {
    debugLog('--- setSaved: $lookId / $isSaved ---');
    final uri = Uri.parse('$_baseUrl/$lookId');
    final res = await withAuth((token) => http.patch(uri, headers: authHeaders(token), body: jsonEncode({'is_saved': isSaved})));
    decodeMap(res, op: 'setSaved');
  }

  Future<void> deleteLook(int jobId) async {
    debugLog('--- deleteLook ---');
    final uri = Uri.parse('$_baseUrl/$jobId');
    final res = await withAuth((token) => http.delete(uri, headers: authHeaders(token)));

    if (res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404) {
      return;
    }
    throw Exception('deleteLook failed (${res.statusCode}): ${res.body}');
  }
}
