import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'base_service.dart';

class RecommendService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/recommendations';

  Future<Map<String, dynamic>> getRecommend(String occasion, String style, int temperature) async {
    debugPrint('--- getRecommend ---');
    final token = await getSafeToken();
    
    final uri = Uri.parse('$_baseUrl/outfits').replace(queryParameters: {
      'occasion': occasion,
      'style': style,
      'temperature_c': temperature.toString(),
    });
    
    final res = await http.get(uri, headers: authHeaders(token));
    throwIfAuthExpired(res);
    
    final envelope = decodeMap(res, op: 'getRecommend');
    final data = envelope['data'];

    if (data is! Map<String, dynamic>) {
      throw Exception('getRecommend: response missing outfit data object');
    }
    return data;
  }

  Future<void> saveRecommend(Map<String, dynamic> recommend) async {
    debugPrint('--- saveRecommend ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/outfits');
    
    final body = {
      'occasion': recommend['occasion'] ?? '',
      'style': recommend['style'] ?? '',
      'temperature_c': recommend['temperature_c'] ?? 0,
      'title': recommend['outfit_name'] ?? '',
      'note': recommend['note'] ?? '',
      'reasoning': recommend['reason'] ?? '',
      'items': (recommend['items'] as List<dynamic>?)?.map((item) => {
        'garment_id': item['garment_id'],
        'layer': item['layer'] ?? '',
        'order': item['order'] ?? 0,
      }).toList() ?? [],
    };

    final res = await http.post(
      uri,
      headers: authHeaders(token),
      body: jsonEncode(body),
    );
    throwIfAuthExpired(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('saveRecommend failed (${res.statusCode}): ${res.body}');
    }
  }
}
