import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/trip.dart';
import '../services/trip_service.dart';

final tripsProvider = AsyncNotifierProvider<TripsNotifier, List<Trip>>(
  TripsNotifier.new,
);

class TripsNotifier extends AsyncNotifier<List<Trip>> {
  @override
  Future<List<Trip>> build() => TripService().getTrips();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => TripService().getTrips());
  }

  void add(Trip trip) {
    final current = state.value ?? [];
    state = AsyncData([trip, ...current]);
  }

  void remove(String id) {
    final current = state.value ?? [];
    state = AsyncData(current.where((t) => t.id != id).toList());
  }

  void updateTrip(Trip trip) {
    final current = state.value ?? [];
    state = AsyncData(current.map((t) => t.id == trip.id ? trip : t).toList());
  }
}
