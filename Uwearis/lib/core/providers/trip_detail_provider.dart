import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/garment.dart';
import '../../data/trip_plan.dart';
import '../services/trip_service.dart';
import '../utils/signed_url.dart';
import 'retry_policy.dart';

/// One trip's day-by-day plan plus its packed suitcase.
class TripDetail {
  final List<TripDayOutfit> days;
  final List<Garment> suitcase;

  const TripDetail({this.days = const [], this.suitcase = const []});

  Set<int> get suitcaseIds => {
    for (final g in suitcase)
      if (g.id != null) g.id!,
  };

  bool get hasTripPlan => days.any((d) => d.optionId != null);

  bool get hasStaleImages => anySignedUrlExpired([
    for (final day in days) ...[
      day.resultImageUrl,
      for (final g in day.garments) g.imageUrl,
    ],
    for (final g in suitcase) g.imageUrl,
  ]);

  TripDetail copyWith({List<TripDayOutfit>? days, List<Garment>? suitcase}) =>
      TripDetail(days: days ?? this.days, suitcase: suitcase ?? this.suitcase);
}

/// Kept for the whole session, so only a trip's first visit waits on the
/// network. Pages write changes back through the mutation methods instead of
/// re-fetching on return.
final tripDetailProvider =
    AsyncNotifierProvider.family<TripDetailNotifier, TripDetail, int>(
      TripDetailNotifier.new,
      retry: appRetryPolicy,
    );

class TripDetailNotifier extends AsyncNotifier<TripDetail> {
  TripDetailNotifier(this.tripId);

  final int tripId;

  // Bumped by every local mutation. A reload that started before one is
  // dropped — its response may predate that change and would overwrite it.
  int _mutationCount = 0;

  @override
  Future<TripDetail> build() => _fetchTripDetail();

  // `GET /plan` has the options but only suitcase ids; `GET /{id}` has the
  // suitcase garments' details.
  Future<TripDetail> _fetchTripDetail() async {
    final (plan, suitcase) = await (
      TripService().getTripPlan(tripId),
      _fetchSuitcase(),
    ).wait;
    return TripDetail(days: plan.days, suitcase: suitcase);
  }

  Future<List<Garment>> _fetchSuitcase() async {
    final data = await TripService().getTrip(tripId);
    return ((data['suitcase_items'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Garment.fromTripItemJson)
        .toList();
  }

  TripDetail get _current => state.value ?? const TripDetail();

  void _mutate(TripDetail updated) {
    _mutationCount++;
    state = AsyncData(updated);
  }

  /// Re-fetches the whole detail in place. Unlike a `refresh()` this never
  /// drops to [AsyncLoading] (the pages keep showing what they have), and
  /// errors propagate to the caller instead of replacing the cached data.
  Future<void> reloadTripDetail() async {
    final startedAt = _mutationCount;
    final fresh = await _fetchTripDetail();
    if (startedAt == _mutationCount) state = AsyncData(fresh);
  }

  /// Re-fetches just the plan, after a `generate` changed it server-side.
  Future<void> reloadPlan() async {
    final startedAt = _mutationCount;
    final plan = await TripService().getTripPlan(tripId);
    if (startedAt == _mutationCount) {
      state = AsyncData(_current.copyWith(days: plan.days));
    }
  }

  /// Re-fetches just the suitcase and returns whatever is current afterward.
  Future<List<Garment>> reloadSuitcase() async {
    final startedAt = _mutationCount;
    final suitcase = await _fetchSuitcase();
    if (startedAt == _mutationCount) {
      state = AsyncData(_current.copyWith(suitcase: suitcase));
    }
    return _current.suitcase;
  }

  /// Replaces the suitcase with what the caller just committed.
  void setSuitcase(List<Garment> suitcase) {
    _mutate(_current.copyWith(suitcase: List.unmodifiable(suitcase)));
  }

  void addSuitcaseGarments(List<Garment> garments) {
    final ids = _current.suitcaseIds;
    setSuitcase([
      ..._current.suitcase,
      for (final g in garments)
        if (g.id != null && !ids.contains(g.id)) g,
    ]);
  }

  void removeSuitcaseGarment(int garmentId) {
    setSuitcase(_current.suitcase.where((g) => g.id != garmentId).toList());
  }

  /// Matched by option, not index, so a late result can't patch the wrong
  /// day. No-op if no day holds [optionId] anymore.
  void updateDayOutfit(
    int optionId,
    TripDayOutfit Function(TripDayOutfit current) update,
  ) {
    if (!_current.days.any((d) => d.optionId == optionId)) return;
    _mutate(
      _current.copyWith(
        days: [
          for (final day in _current.days)
            day.optionId == optionId ? update(day) : day,
        ],
      ),
    );
  }
}
