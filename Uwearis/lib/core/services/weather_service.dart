import 'dart:async';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// `GET /weather`: current conditions, a 7-day forecast and the place name,
/// cached server-side for 30 minutes. Free (no points).
class WeatherService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/weather';

  /// With [lat]/[lon] the backend uses that position and names it in the
  /// user's profile `locale`; without them it falls back to the profile's
  /// `location`. Coordinates go out at 2 decimals (~1 km): the backend
  /// queries and caches at that precision, and logs the query string.
  ///
  /// Returns the response's `data` object.
  Future<Map<String, dynamic>> getWeather({double? lat, double? lon}) async {
    assert((lat == null) == (lon == null), 'send both lat and lon, or neither');
    final hasPosition = lat != null && lon != null;
    debugLog('--- getWeather: ${hasPosition ? 'gps' : 'profile location'} ---');
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: hasPosition
          ? {'lat': lat.toStringAsFixed(2), 'lon': lon.toStringAsFixed(2)}
          : null,
    );
    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );
    final data = decodeMap(res, op: 'getWeather')['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getWeather: response missing data object');
    }
    return data;
  }
}
