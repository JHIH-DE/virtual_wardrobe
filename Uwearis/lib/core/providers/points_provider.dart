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

  // A balance change arrived while a re-read was in flight. That read may
  // have reached the server before the change, so one more runs after it;
  // any number of changes meanwhile share that one.
  bool _reloadAgain = false;

  // Riverpod keeps this notifier across invalidate (a sign-in) and `ref` is
  // always the newest build's, so `ref.mounted` can't tell a reply to an
  // earlier build — the previous account's — from a current one. Bumped on
  // every dispose/rebuild; a reply from another generation is dropped.
  int _generation = 0;

  bool _isCurrent(int generation) => generation == _generation;

  @override
  Future<PointsSummary> build() async {
    final generation = _generation;
    final changes = PointsService.balanceChanges.listen((_) {
      if (_reloading != null) {
        _reloadAgain = true;
      } else {
        unawaited(reloadPoints());
      }
    });
    ref.onDispose(() {
      _generation++;
      _reloading = null;
      _reloadAgain = false;
      changes.cancel();
      _nextGrantTimer?.cancel();
    });
    final summary = await PointsService().getPoints();
    if (_isCurrent(generation)) _scheduleNextGrant(summary);
    return summary;
  }

  Future<void> refresh() async {
    final generation = _generation;
    state = const AsyncLoading();
    final next = await AsyncValue.guard(PointsService().getPoints);
    if (!_isCurrent(generation)) return;
    state = next;
    final summary = next.value;
    if (summary != null) _scheduleNextGrant(summary);
  }

  /// Keeps the shown balance while re-reading, and on failure; concurrent
  /// calls share one request, and its trailing re-read when a balance
  /// change lands meanwhile. Null when the last read failed, or when the
  /// provider was rebuilt (another account) before it answered.
  Future<PointsSummary?> reloadPoints() =>
      _reloading ??= _reloadUntilCurrent(_generation);

  Future<PointsSummary?> _reloadUntilCurrent(int generation) async {
    PointsSummary? latest;
    do {
      _reloadAgain = false;
      latest = await _reload(generation);
      // A rebuild already reset _reloading / _reloadAgain for its own reads.
      if (!_isCurrent(generation)) return null;
    } while (_reloadAgain);
    // In the same synchronous step as the check above, so a change can't
    // land between them and be lost.
    _reloading = null;
    return latest;
  }

  Future<PointsSummary?> _reload(int generation) async {
    try {
      final summary = await PointsService().getPoints();
      if (!_isCurrent(generation)) return null;
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
