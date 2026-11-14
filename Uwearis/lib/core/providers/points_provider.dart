import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/points.dart';
import '../services/points_service.dart';
import '../utils/debug_log.dart';
import 'retry_policy.dart';

/// The balance on the wardrobe nav bar, Settings and the Points page. Re-reads
/// itself after any charged AI request ([PointsService.balanceChanges]) and
/// just after the next daily grant.
final pointsProvider = AsyncNotifierProvider<PointsNotifier, PointsSummary>(
  PointsNotifier.new,
  retry: appRetryPolicy,
);

class PointsNotifier extends AsyncNotifier<PointsSummary> {
  Timer? _nextGrantTimer;
  Future<PointsSummary?>? _reloading;

  @override
  Future<PointsSummary> build() async {
    final changes = PointsService.balanceChanges.listen((_) {
      unawaited(reloadPoints());
    });
    ref.onDispose(() {
      changes.cancel();
      _nextGrantTimer?.cancel();
    });
    final summary = await PointsService().getPoints();
    _scheduleNextGrant(summary);
    return summary;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(PointsService().getPoints);
    final summary = state.value;
    if (summary != null) _scheduleNextGrant(summary);
  }

  /// Keeps the shown balance while re-reading, and on failure; concurrent
  /// calls share one request. Null when the read failed.
  Future<PointsSummary?> reloadPoints() {
    return _reloading ??= _reload().whenComplete(() => _reloading = null);
  }

  Future<PointsSummary?> _reload() async {
    try {
      final summary = await PointsService().getPoints();
      if (!ref.mounted) return summary;
      state = AsyncData(summary);
      _scheduleNextGrant(summary);
      return summary;
    } catch (e) {
      debugLog('reloadPoints failed: $e');
      return null;
    }
  }

  /// A few seconds past midnight Taipei, so the grant has landed.
  void _scheduleNextGrant(PointsSummary summary) {
    _nextGrantTimer?.cancel();
    if (summary.nextGrant <= 0) return;
    final delay =
        summary.nextClaimAt.difference(DateTime.now()) +
        const Duration(seconds: 5);
    if (delay.isNegative) return;
    _nextGrantTimer = Timer(delay, () => unawaited(reloadPoints()));
  }
}
