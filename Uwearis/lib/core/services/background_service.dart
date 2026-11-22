import 'dart:async';

import 'package:http/http.dart' as http;

import '../../data/background_option.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// `/backgrounds`: the try-on backgrounds, the same list for every user.
/// Free (no points).
class BackgroundService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/backgrounds';

  /// In the backend's display order — keep it, don't re-sort.
  Future<List<BackgroundOption>> getBackgrounds() async {
    debugLog('--- getBackgrounds ---');
    final uri = Uri.parse(_baseUrl);
    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );
    final data = decodeMap(res, op: 'getBackgrounds')['data'];
    if (data is! List) {
      throw Exception('getBackgrounds: response missing backgrounds list');
    }
    return [
      for (final b in data)
        if (b is Map<String, dynamic> && b['id'] is num)
          BackgroundOption.fromJson(b),
    ];
  }
}
