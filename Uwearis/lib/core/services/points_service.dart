import 'dart:async';

import 'package:http/http.dart' as http;

import '../../data/points.dart';
import '../config/app_config.dart';
import '../utils/analytics.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// `/points`. The daily grant needs no call: the backend applies it on the
/// day's first points-touching request (`/users/me`, [getPoints], any
/// charged AI call).
class PointsService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/points';

  static final StreamController<void> _balanceChanges =
      StreamController<void>.broadcast(sync: false);

  /// Fires after a request that may have charged or refunded points. The
  /// charged endpoints don't return the new balance, so a listener re-reads.
  static Stream<void> get balanceChanges => _balanceChanges.stream;

  /// The last [getPoints] result this session, for copy that has no
  /// provider access (the insufficient-points message).
  static PointsSummary? lastSummary;

  /// Call from every charged AI request, success or failure (a failure is
  /// refunded server-side, which also moves the balance back).
  static void notifyBalanceChanged() => _balanceChanges.add(null);

  /// Wraps a charged AI request; see [notifyBalanceChanged].
  static Future<T> charged<T>(
    Future<T> Function() send, {
    required ChargedFeature feature,
  }) async {
    try {
      final result = await send();
      if (result is http.Response && result.statusCode == 402) {
        Analytics.pointsInsufficient(feature);
      }
      return result;
    } finally {
      notifyBalanceChanged();
    }
  }

  Future<PointsSummary> getPoints() async {
    debugLog('--- getPoints ---');
    final uri = Uri.parse(_baseUrl);
    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );
    final data = decodeMap(res, op: 'getPoints')['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getPoints: response missing data object');
    }
    return lastSummary = PointsSummary.fromJson(data);
  }

  /// Newest first. [size] is 1–100.
  Future<PointsTransactionPage> getTransactions({
    int page = 1,
    int size = 20,
  }) async {
    debugLog('--- getTransactions: page=$page size=$size ---');
    final uri = Uri.parse(
      '$_baseUrl/transactions',
    ).replace(queryParameters: {'page': '$page', 'size': '$size'});
    final res = await withAuth(
      (token) => http
          .get(uri, headers: authHeaders(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );
    final data = decodeMap(res, op: 'getTransactions')['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getTransactions: response missing data object');
    }
    return PointsTransactionPage.fromJson(data);
  }
}
