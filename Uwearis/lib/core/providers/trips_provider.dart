import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/trip.dart';
import '../services/trip_service.dart';
import 'retry_policy.dart';

final tripsProvider = AsyncNotifierProvider<TripsNotifier, List<Trip>>(
  TripsNotifier.new,
  retry: appRetryPolicy,
);

class TripsNotifier extends AsyncNotifier<List<Trip>> {
  // Riverpod keeps this notifier across invalidate (a sign-in), so a refresh
  // from an earlier build — maybe the previous account's — is told apart by
  // this, bumped when a build is disposed.
  int _generation = 0;

  @override
  Future<List<Trip>> build() {
    ref.onDispose(() => _generation++);
    return TripService().getTrips();
  }

  Future<void> refresh() async {
    final generation = _generation;
    state = const AsyncLoading();
    final next = await AsyncValue.guard(() => TripService().getTrips());
    if (generation == _generation) state = next;
  }

  void addTrip(Trip trip) {
    final current = state.value ?? [];
    state = AsyncData([trip, ...current]);
  }

  void removeTrip(String id) {
    final current = state.value ?? [];
    state = AsyncData(current.where((t) => t.id != id).toList());
  }

  void updateTrip(Trip trip) {
    final current = state.value ?? [];
    state = AsyncData(current.map((t) => t.id == trip.id ? trip : t).toList());
  }
}
