import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/garment.dart';
import '../../data/trip_outfit.dart';
import '../services/trip_service.dart';
import 'retry_policy.dart';

/// One trip's outfit collection plus its packed suitcase. Kept for the whole
/// session, so only a trip's first visit waits on the network. Pages write
/// changes back through the mutation methods instead of re-fetching on return.
final tripDetailProvider =
    AsyncNotifierProvider.family<TripDetailNotifier, TripOutfitCollection, int>(
      TripDetailNotifier.new,
      retry: appRetryPolicy,
    );

class TripDetailNotifier extends AsyncNotifier<TripOutfitCollection> {
  TripDetailNotifier(this.tripId);

  final int tripId;

  // Bumped by every local mutation. A reload that started before one is
  // dropped — its response may predate that change and would overwrite it.
  int _mutationCount = 0;

  @override
  Future<TripOutfitCollection> build() => TripService().getTripOutfits(tripId);

  TripOutfitCollection get _current =>
      state.value ?? const TripOutfitCollection();

  void _mutate(TripOutfitCollection updated) {
    _mutationCount++;
    state = AsyncData(updated);
  }

  /// Re-fetches in place. Unlike a `refresh()` this never drops to
  /// [AsyncLoading] (the pages keep showing what they have), and errors
  /// propagate to the caller instead of replacing the cached data.
  Future<void> reloadTripDetail() async {
    final startedAt = _mutationCount;
    final fresh = await TripService().getTripOutfits(tripId);
    if (startedAt == _mutationCount) state = AsyncData(fresh);
  }

  /// Re-fetches and returns whatever suitcase is current afterward.
  Future<List<Garment>> reloadSuitcase() async {
    await reloadTripDetail();
    return _current.suitcase;
  }

  /// Applies a collection endpoint's response, which is always the whole
  /// collection.
  void setCollection(TripOutfitCollection collection) => _mutate(collection);

  /// Replaces the suitcase with what the caller just committed. Missing
  /// garments are derived from it, so outfits need no patching.
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
}
