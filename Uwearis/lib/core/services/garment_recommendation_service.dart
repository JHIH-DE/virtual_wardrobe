import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/style_type.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// Add Outfit's "Complete with AI": the backend fills in the rest of an
/// outfit around the picked garments. Text-only — no try-on image, no
/// OutfitGroup created. Locking is frontend-only; the backend never sees it.
class GarmentRecommendationService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/outfit/advice';

  /// Accumulate [excludeGarmentIds] across re-runs so a rejected suggestion
  /// doesn't resurface. [garmentIds] wins over the exclude list.
  ///
  /// The backend ignores `style` for now and always infers it from the
  /// user's Style Taste analysis.
  Future<List<int>> completeOutfit({
    required List<int> garmentIds,
    StyleType? style,
    double? temperatureC,
    List<int> excludeGarmentIds = const [],
  }) async {
    debugLog(
      '--- completeOutfit: garmentIds=$garmentIds '
      'excludeGarmentIds=$excludeGarmentIds '
      'style=${style?.apiValue} ---',
    );
    final uri = Uri.parse(_baseUrl);
    final payload = <String, dynamic>{
      'style': ?style?.apiValue,
      'temperature_c': temperatureC,
      'garment_ids': garmentIds,
      'exclude_garment_ids': excludeGarmentIds,
    };
    final res = await withAuth(
      (token) => http
          .post(uri, headers: authHeaders(token), body: jsonEncode(payload))
          .timeout(const Duration(seconds: 45)),
    );
    final envelope = decodeMap(res, op: 'completeOutfit');
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('completeOutfit: response missing outfit data object');
    }
    final ids = data['selected_garment_ids'];
    if (ids is! List) {
      throw Exception('completeOutfit: response missing selected_garment_ids');
    }
    return ids.map((id) => (id as num).toInt()).toList();
  }
}
