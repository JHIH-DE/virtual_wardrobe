import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

class RecommendService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/recommendations';

  Future<Map<String, dynamic>> getRecommend(
    String occasion,
    String style,
    int temperature,
  ) async {
    debugLog('--- getRecommend ---');
    final uri = Uri.parse('$_baseUrl/outfits').replace(
      queryParameters: {
        'occasion': occasion,
        'style': style,
        'temperature_c': temperature.toString(),
      },
    );

    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'getRecommend');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('getRecommend: response missing outfit data object');
    }
    return data;
  }

  Future<void> saveRecommend(Map<String, dynamic> recommend) async {
    debugLog('--- saveRecommend ---');
    final uri = Uri.parse('$_baseUrl/outfits');

    final body = {
      'occasion': recommend['occasion'] ?? '',
      'style': recommend['style'] ?? '',
      'temperature_c': recommend['temperature_c'] ?? 0,
      'title': recommend['outfit_name'] ?? '',
      'note': recommend['note'] ?? '',
      'reasoning': recommend['reason'] ?? '',
      'items':
          (recommend['items'] as List<dynamic>?)
              ?.map(
                (item) => {
                  'garment_id': item['garment_id'],
                  'layer': item['layer'] ?? '',
                  'order': item['order'] ?? 0,
                },
              )
              .toList() ??
          [],
    };

    final res = await withAuth(
      (token) =>
          http.post(uri, headers: authHeaders(token), body: jsonEncode(body)),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('saveRecommend failed (${res.statusCode}): ${res.body}');
    }
  }
}
